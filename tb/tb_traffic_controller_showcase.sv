`timescale 1ns/1ps
`default_nettype none

// Directed, human-readable waveform demonstration. Unlike the exhaustive
// self-checking regression, this testbench leaves generous gaps and exposes
// scenario/event markers to make a GTKWave presentation easy to follow.
module tb_traffic_controller_showcase;
    localparam int STARTUP_T   = 2;
    localparam int MIN_GREEN_T = 3;
    localparam int MAX_GREEN_T = 6;
    localparam int AMBER_T     = 2;
    localparam int ALL_RED_T   = 1;
    localparam int PED_WALK_T  = 3;
    localparam int PED_FLASH_T = 4;
    localparam int PED_CLEAR_T = 1;

    localparam logic [3:0] S_STARTUP   = 4'd0;
    localparam logic [3:0] S_NS_GREEN  = 4'd1;
    localparam logic [3:0] S_NS_AMBER  = 4'd2;
    localparam logic [3:0] S_EW_GREEN  = 4'd4;
    localparam logic [3:0] S_PED_WALK  = 4'd7;
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

    // 1=normal, 2=adaptive max, 3=pedestrian, 4=emergency.
    logic [2:0] scenario_id = 3'd0;
    // Event codes are documented in waveforms/README.md.
    logic [7:0] event_marker = 8'd0;

    always #5 clk = ~clk;

    traffic_controller #(
        .STARTUP_TICKS(STARTUP_T),
        .MIN_GREEN_TICKS(MIN_GREEN_T),
        .MAX_GREEN_TICKS(MAX_GREEN_T),
        .AMBER_TICKS(AMBER_T),
        .ALL_RED_TICKS(ALL_RED_T),
        .PED_WALK_TICKS(PED_WALK_T),
        .PED_FLASH_TICKS(PED_FLASH_T),
        .PED_CLEAR_TICKS(PED_CLEAR_T)
    ) dut (
        .clk_i(clk), .reset_i(reset), .tick_i(tick),
        .ns_vehicle_i(ns_vehicle), .ew_vehicle_i(ew_vehicle),
        .ped_request_i(ped_request), .emergency_i(emergency),
        .ns_red_o(ns_red), .ns_amber_o(ns_amber), .ns_green_o(ns_green),
        .ew_red_o(ew_red), .ew_amber_o(ew_amber), .ew_green_o(ew_green),
        .ped_walk_o(ped_walk), .ped_stop_o(ped_stop),
        .emergency_o(emergency_active),
        .ped_request_pending_o(ped_pending),
        .state_code_o(state_code),
        .state_elapsed_ticks_o(state_elapsed),
        .state_remaining_ticks_o(state_remaining)
    );

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
            repeat (2) @(negedge clk);
            if (state_code !== S_STARTUP) $fatal(1, "Reset did not enter startup");
        end
    endtask

    initial begin : showcase
        integer guard;

        $dumpfile("waveforms/traffic_showcase.vcd");
        $dumpvars(0, tb_traffic_controller_showcase);
        repeat (2) @(negedge clk);

        // Scenario 1: exact normal sequence with minimum green durations.
        scenario_id = 3'd1;
        event_marker = 8'd10; // scenario start
        apply_reset();
        event_marker = 8'd11; // startup timing
        advance_ticks(STARTUP_T);
        if (state_code !== S_NS_GREEN) $fatal(1, "Normal: missing NS green");
        event_marker = 8'd12; // normal NS->EW->NS sequence
        advance_ticks(MIN_GREEN_T + AMBER_T + ALL_RED_T);
        if (state_code !== S_EW_GREEN) $fatal(1, "Normal: missing EW green");
        advance_ticks(MIN_GREEN_T + AMBER_T + ALL_RED_T);
        if (state_code !== S_NS_GREEN) $fatal(1, "Normal: cycle did not return to NS");
        repeat (3) @(negedge clk);

        // Scenario 2: active NS traffic extends beyond minimum but maximum wins.
        scenario_id = 3'd2;
        event_marker = 8'd20;
        apply_reset();
        advance_ticks(STARTUP_T);
        ns_vehicle = 1'b1;
        event_marker = 8'd21; // demand held, extension begins after minimum
        advance_ticks(MIN_GREEN_T);
        if (state_code !== S_NS_GREEN) $fatal(1, "Adaptive: no extension");
        advance_ticks(MAX_GREEN_T - MIN_GREEN_T - 1);
        if (state_code !== S_NS_GREEN) $fatal(1, "Adaptive: early cutoff");
        event_marker = 8'd22; // next tick is hard maximum
        pulse_tick();
        if (state_code !== S_NS_AMBER) $fatal(1, "Adaptive: maximum not enforced");
        ns_vehicle = 1'b0;
        repeat (3) @(negedge clk);

        // Scenario 3: one-clock pedestrian pulse is remembered and safely served.
        scenario_id = 3'd3;
        event_marker = 8'd30;
        apply_reset();
        advance_ticks(STARTUP_T);
        pulse_tick();
        event_marker = 8'd31; // short request pulse
        request_once();
        if (!ped_pending) $fatal(1, "Pedestrian request was not latched");
        event_marker = 8'd32; // pending across remaining road phases
        guard = 0;
        while ((state_code != S_PED_WALK) && (guard < 50)) begin
            pulse_tick();
            guard = guard + 1;
        end
        if (state_code !== S_PED_WALK) $fatal(1, "Pedestrian service timed out");
        event_marker = 8'd33; // walk, flash, and clear
        advance_ticks(PED_WALK_T + PED_FLASH_T + PED_CLEAR_T);
        if (state_code !== S_NS_GREEN || ped_pending)
            $fatal(1, "Pedestrian phase did not clear and return to NS");
        repeat (3) @(negedge clk);

        // Scenario 4: emergency entry ignores tick, release is sticky, reset recovers.
        scenario_id = 3'd4;
        event_marker = 8'd40;
        apply_reset();
        advance_ticks(STARTUP_T);
        pulse_tick();
        tick = 1'b0;
        event_marker = 8'd41; // emergency asserted between timer ticks
        @(negedge clk); emergency = 1'b1;
        @(negedge clk);
        if (state_code !== S_EMERGENCY || !emergency_active)
            $fatal(1, "Emergency did not enter on system clock");
        event_marker = 8'd42; // release without reset remains locked
        emergency = 1'b0;
        advance_ticks(3);
        if (state_code !== S_EMERGENCY) $fatal(1, "Emergency auto-recovered");
        event_marker = 8'd43; // reset after clear restarts startup
        apply_reset();
        advance_ticks(STARTUP_T);
        if (state_code !== S_NS_GREEN) $fatal(1, "Emergency recovery failed");

        event_marker = 8'd99;
        repeat (5) @(negedge clk);
        $display("SHOWCASE PASS: waveform scenarios completed");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "SHOWCASE TIMEOUT");
    end
endmodule

`default_nettype wire
