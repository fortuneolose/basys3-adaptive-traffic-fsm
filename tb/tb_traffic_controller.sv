`timescale 1ns/1ps
`default_nettype none

module tb_traffic_controller;
    localparam int STARTUP_T = 2;
    localparam int MIN_GREEN_T = 3;
    localparam int MAX_GREEN_T = 5;
    localparam int AMBER_T = 2;
    localparam int ALL_RED_T = 1;
    localparam int PED_WALK_T = 2;
    localparam int PED_FLASH_T = 2;
    localparam int PED_CLEAR_T = 1;

    localparam logic [3:0] S_STARTUP   = 4'd0;
    localparam logic [3:0] S_NS_GREEN  = 4'd1;
    localparam logic [3:0] S_NS_AMBER  = 4'd2;
    localparam logic [3:0] S_AR_EW     = 4'd3;
    localparam logic [3:0] S_EW_GREEN  = 4'd4;
    localparam logic [3:0] S_EW_AMBER  = 4'd5;
    localparam logic [3:0] S_AR_NS     = 4'd6;
    localparam logic [3:0] S_PED_WALK  = 4'd7;
    localparam logic [3:0] S_PED_FLASH = 4'd8;
    localparam logic [3:0] S_PED_CLEAR = 4'd9;
    localparam logic [3:0] S_EMERGENCY = 4'd10;

    logic clk = 1'b0;
    logic reset = 1'b0;
    logic tick = 1'b0;
    logic ns_vehicle = 1'b0;
    logic ew_vehicle = 1'b0;
    logic ped_request = 1'b0;
    logic emergency = 1'b0;

    logic ns_red, ns_amber, ns_green;
    logic ew_red, ew_amber, ew_green;
    logic ped_walk, ped_stop, emergency_active, ped_pending;
    logic [3:0] state_code;
    logic [31:0] state_elapsed, state_remaining;

    logic db_button = 1'b0;
    logic db_level, db_pressed;
    integer failures = 0;
    integer checks = 0;
    logic monitor_enable = 1'b0;

    always #5 clk = ~clk;

    traffic_controller #(
        .STARTUP_TICKS(STARTUP_T), .MIN_GREEN_TICKS(MIN_GREEN_T),
        .MAX_GREEN_TICKS(MAX_GREEN_T), .AMBER_TICKS(AMBER_T),
        .ALL_RED_TICKS(ALL_RED_T), .PED_WALK_TICKS(PED_WALK_T),
        .PED_FLASH_TICKS(PED_FLASH_T), .PED_CLEAR_TICKS(PED_CLEAR_T)
    ) dut (
        .clk_i(clk), .reset_i(reset), .tick_i(tick),
        .ns_vehicle_i(ns_vehicle), .ew_vehicle_i(ew_vehicle),
        .ped_request_i(ped_request), .emergency_i(emergency),
        .ns_red_o(ns_red), .ns_amber_o(ns_amber), .ns_green_o(ns_green),
        .ew_red_o(ew_red), .ew_amber_o(ew_amber), .ew_green_o(ew_green),
        .ped_walk_o(ped_walk), .ped_stop_o(ped_stop),
        .emergency_o(emergency_active),
        .ped_request_pending_o(ped_pending), .state_code_o(state_code),
        .state_elapsed_ticks_o(state_elapsed),
        .state_remaining_ticks_o(state_remaining)
    );

    button_debouncer #(.STABLE_CYCLES(3)) debounce_dut (
        .clk_i(clk), .reset_i(reset), .button_i(db_button),
        .level_o(db_level), .pressed_o(db_pressed)
    );

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (!condition) begin
                failures = failures + 1;
                $display("FAIL @ %0t: %s (state=%0d elapsed=%0d)",
                         $time, message, state_code, state_elapsed);
            end
        end
    endtask

    task automatic expect_state(input logic [3:0] expected, input string label_text);
        check(state_code === expected,
              $sformatf("%s: expected state %0d, got %0d", label_text, expected, state_code));
    endtask

    task automatic pulse_tick;
        begin
            @(negedge clk); tick = 1'b1;
            @(negedge clk); tick = 1'b0;
        end
    endtask

    task automatic advance_ticks(input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) pulse_tick();
        end
    endtask

    task automatic request_once;
        begin
            @(negedge clk); ped_request = 1'b1;
            @(negedge clk); ped_request = 1'b0;
        end
    endtask

    task automatic apply_reset;
        begin
            tick = 1'b0;
            emergency = 1'b0;
            ped_request = 1'b0;
            ns_vehicle = 1'b0;
            ew_vehicle = 1'b0;
            @(negedge clk); reset = 1'b1;
            repeat (2) @(negedge clk);
            reset = 1'b0;
            @(negedge clk);
            expect_state(S_STARTUP, "reset enters startup");
            check(state_elapsed === 0, "reset clears elapsed timer");
            check(!ped_pending, "reset clears pending request");
        end
    endtask

    task automatic expect_fixed_duration(
        input logic [3:0] current_state,
        input integer duration,
        input logic [3:0] next_state,
        input string label_text
    );
        integer i;
        begin
            expect_state(current_state, {label_text, " entry"});
            for (i = 1; i < duration; i = i + 1) begin
                pulse_tick();
                expect_state(current_state, {label_text, " before boundary"});
                check(state_elapsed === i, {label_text, " elapsed count"});
            end
            pulse_tick();
            expect_state(next_state, {label_text, " exact boundary"});
            check(state_elapsed === 0, {label_text, " timer resets on transition"});
        end
    endtask

    task automatic reach_state(input logic [3:0] target);
        integer guard;
        begin
            apply_reset();
            if (target >= S_PED_WALK && target <= S_PED_CLEAR) request_once();
            guard = 0;
            while ((state_code !== target) && (guard < 100)) begin
                pulse_tick();
                guard = guard + 1;
            end
            check(guard < 100, $sformatf("reach state %0d without timeout", target));
            expect_state(target, "reach_state target");
        end
    endtask

    // Simulator-compatible continuous safety monitors.
    always @(negedge clk) begin
        if (monitor_enable && !reset) begin
            check(({ns_red, ns_amber, ns_green} === 3'b100) ||
                  ({ns_red, ns_amber, ns_green} === 3'b010) ||
                  ({ns_red, ns_amber, ns_green} === 3'b001),
                  "NS lamps are exactly one-hot");
            check(({ew_red, ew_amber, ew_green} === 3'b100) ||
                  ({ew_red, ew_amber, ew_green} === 3'b010) ||
                  ({ew_red, ew_amber, ew_green} === 3'b001),
                  "EW lamps are exactly one-hot");
            check(!(ns_green && ew_green), "conflicting greens never overlap");
            check(!(ped_walk && (ns_green || ew_green)),
                  "walk never overlaps a vehicle green");
            if ((state_code >= S_PED_WALK && state_code <= S_PED_CLEAR) ||
                (state_code == S_EMERGENCY)) begin
                check(ns_red && ew_red, "pedestrian/emergency phases are all-red");
            end
        end
    end

    initial begin : regression
        integer i;
        integer guard;
        logic flash_first;

        $dumpfile("build/traffic_controller.vcd");
        $dumpvars(0, tb_traffic_controller);
        repeat (2) @(negedge clk);
        monitor_enable = 1'b1;

        $display("TEST: reset, exact durations, and complete normal cycle");
        apply_reset();
        check(ns_red && ew_red && ped_stop && !ped_walk, "startup safe outputs");
        expect_fixed_duration(S_STARTUP, STARTUP_T, S_NS_GREEN, "startup");
        expect_fixed_duration(S_NS_GREEN, MIN_GREEN_T, S_NS_AMBER, "NS minimum green");
        expect_fixed_duration(S_NS_AMBER, AMBER_T, S_AR_EW, "NS amber");
        check(ns_red && ew_red, "all-red clearance before EW green");
        expect_fixed_duration(S_AR_EW, ALL_RED_T, S_EW_GREEN, "all-red to EW");
        expect_fixed_duration(S_EW_GREEN, MIN_GREEN_T, S_EW_AMBER, "EW minimum green");
        expect_fixed_duration(S_EW_AMBER, AMBER_T, S_AR_NS, "EW amber");
        check(ns_red && ew_red, "all-red clearance before NS green");
        expect_fixed_duration(S_AR_NS, ALL_RED_T, S_NS_GREEN, "all-red to NS");

        $display("TEST: NS extension, conflict response, and maximum enforcement");
        apply_reset(); advance_ticks(STARTUP_T);
        ns_vehicle = 1'b1;
        advance_ticks(MIN_GREEN_T);
        expect_state(S_NS_GREEN, "NS extends with active demand");
        ew_vehicle = 1'b1;
        pulse_tick();
        expect_state(S_NS_AMBER, "NS ends after minimum when EW waits");
        apply_reset(); advance_ticks(STARTUP_T);
        ns_vehicle = 1'b1;
        advance_ticks(MAX_GREEN_T - 1);
        expect_state(S_NS_GREEN, "NS remains green before maximum boundary");
        pulse_tick();
        expect_state(S_NS_AMBER, "NS maximum green is absolute");

        $display("TEST: EW extension and maximum enforcement");
        apply_reset(); advance_ticks(STARTUP_T + MIN_GREEN_T + AMBER_T + ALL_RED_T);
        expect_state(S_EW_GREEN, "arrive at EW green");
        ew_vehicle = 1'b1;
        advance_ticks(MIN_GREEN_T);
        expect_state(S_EW_GREEN, "EW extends with active demand");
        advance_ticks(MAX_GREEN_T - MIN_GREEN_T - 1);
        expect_state(S_EW_GREEN, "EW remains before maximum boundary");
        pulse_tick();
        expect_state(S_EW_AMBER, "EW maximum green is absolute");

        $display("TEST: pedestrian request during every major traffic phase");
        for (i = S_STARTUP; i <= S_AR_NS; i = i + 1) begin
            reach_state(i[3:0]);
            request_once();
            check(ped_pending, $sformatf("request latched in state %0d", i));
            guard = 0;
            while ((state_code != S_PED_WALK) && (guard < 100)) begin
                pulse_tick();
                guard = guard + 1;
            end
            check(guard < 100, $sformatf("request from state %0d is served", i));
            check(ped_walk && ns_red && ew_red, "walk phase has safe outputs");
        end

        $display("TEST: short and multiple pedestrian presses");
        apply_reset(); advance_ticks(STARTUP_T);
        request_once();
        check(ped_pending, "one-clock pedestrian pulse is remembered");
        request_once(); request_once();
        check(ped_pending, "multiple requests leave one clean pending bit");
        guard = 0;
        while ((state_code != S_PED_WALK) && (guard < 100)) begin
            pulse_tick(); guard = guard + 1;
        end
        expect_state(S_PED_WALK, "multiple requests produce one pedestrian service");
        expect_fixed_duration(S_PED_WALK, PED_WALK_T, S_PED_FLASH, "ped walk");
        flash_first = ped_stop;
        pulse_tick();
        check(ped_stop != flash_first, "flashing stop toggles each tick");
        pulse_tick();
        expect_state(S_PED_CLEAR, "ped flash exact boundary");
        check(ns_red && ew_red && ped_stop, "ped clear safe outputs");
        pulse_tick();
        expect_state(S_NS_GREEN, "ped clear returns to NS");
        check(!ped_pending, "request clears only after pedestrian service");

        $display("TEST: emergency entry from every non-emergency state");
        for (i = S_STARTUP; i <= S_PED_CLEAR; i = i + 1) begin
            reach_state(i[3:0]);
            tick = 1'b0;
            @(negedge clk); emergency = 1'b1;
            @(negedge clk);
            expect_state(S_EMERGENCY, $sformatf("emergency entry from state %0d", i));
            check(emergency_active && ns_red && ew_red && ped_stop && !ped_walk,
                  "emergency outputs are safe");
            emergency = 1'b0;
            advance_ticks(3);
            expect_state(S_EMERGENCY, "emergency release alone cannot resume");
            apply_reset();
            expect_state(S_STARTUP, "clear emergency plus reset restarts startup");
        end

        $display("TEST: reset while emergency remains asserted");
        reach_state(S_NS_GREEN);
        @(negedge clk); emergency = 1'b1;
        @(negedge clk); reset = 1'b1;
        repeat (2) @(negedge clk);
        expect_state(S_EMERGENCY, "reset cannot override active emergency input");
        emergency = 1'b0; reset = 1'b0;
        advance_ticks(2);
        expect_state(S_EMERGENCY, "release after in-emergency reset remains latched");
        apply_reset();

        $display("TEST: inputs stuck high and starvation bounds");
        apply_reset();
        ns_vehicle = 1'b1; ew_vehicle = 1'b1;
        advance_ticks(STARTUP_T);
        expect_fixed_duration(S_NS_GREEN, MIN_GREEN_T, S_NS_AMBER,
                              "both sensors high NS fairness");
        advance_ticks(AMBER_T + ALL_RED_T);
        expect_fixed_duration(S_EW_GREEN, MIN_GREEN_T, S_EW_AMBER,
                              "both sensors high EW fairness");

        $display("TEST: held button produces one debounced pulse");
        apply_reset();
        db_button = 1'b1;
        guard = 0;
        while (!db_pressed && guard < 10) begin @(negedge clk); guard = guard + 1; end
        check(db_pressed, "debouncer recognizes stable high input");
        repeat (6) begin
            @(negedge clk);
            check(!db_pressed, "held debounced button does not repeat pulse");
        end
        check(db_level, "debounced level remains high while held");
        db_button = 1'b0;
        repeat (4) @(negedge clk);
        check(!db_level, "debouncer recognizes stable release");

        $display("TEST: invalid-state outputs fail safe");
        monitor_enable = 1'b0;
        force dut.state_q = 4'hF;
        #1;
        check(ns_red && ew_red && !ns_amber && !ns_green &&
              !ew_amber && !ew_green && !ped_walk && ped_stop,
              "invalid encoding defaults to all-red");
        release dut.state_q;
        apply_reset();
        monitor_enable = 1'b1;

        if (failures == 0) begin
            $display("TESTBENCH PASS: %0d checks completed", checks);
            $finish;
        end else begin
            $fatal(1, "TESTBENCH FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

    initial begin
        #200000;
        $fatal(1, "TESTBENCH TIMEOUT");
    end
endmodule

`default_nettype wire
