`timescale 1ns/1ps
`default_nettype none

module traffic_controller_top #(
    parameter int unsigned CLOCK_HZ          = 100_000_000,
    parameter int unsigned TIMER_TICK_HZ     = 1,
    parameter int unsigned DEBOUNCE_CYCLES   = 2_000_000,
    parameter int unsigned STARTUP_TICKS     = 2,
    parameter int unsigned MIN_GREEN_TICKS   = 8,
    parameter int unsigned MAX_GREEN_TICKS   = 15,
    parameter int unsigned AMBER_TICKS       = 3,
    parameter int unsigned ALL_RED_TICKS     = 1,
    parameter int unsigned PED_WALK_TICKS    = 6,
    parameter int unsigned PED_FLASH_TICKS   = 4,
    parameter int unsigned PED_CLEAR_TICKS   = 1
) (
    input  wire logic        clk,
    input  wire logic        sw_ns_vehicle,
    input  wire logic        sw_ew_vehicle,
    input  wire logic        sw_emergency,
    input  wire logic        btnC,
    input  wire logic        btnU,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an
);
    logic [4:0] async_inputs;
    logic [4:0] sync_inputs;
    logic ns_vehicle_sync, ew_vehicle_sync, emergency_sync;
    logic reset_level, reset_pressed_unused;
    logic ped_level_unused, ped_pressed, timer_tick;
    logic power_on_reset = 1'b1;

    logic ns_red, ns_amber, ns_green;
    logic ew_red, ew_amber, ew_green;
    logic ped_walk, ped_stop, emergency_active, ped_pending;
    logic [3:0] state_code;
    logic [31:0] state_remaining;
    logic [31:0] _unused_state_elapsed;
    logic [7:0] display_remaining;
    logic [3:0] display_tens;
    logic [3:0] display_ones;
    logic [15:0] display_digits;

    // One-cycle FPGA power-on reset initializes modules that otherwise depend on
    // the debounced centre button. Artix-7 implements the declaration INIT value.
    always_ff @(posedge clk) power_on_reset <= 1'b0;

    assign async_inputs = {btnU, btnC, sw_emergency, sw_ew_vehicle, sw_ns_vehicle};
    assign ns_vehicle_sync = sync_inputs[0];
    assign ew_vehicle_sync = sync_inputs[1];
    assign emergency_sync  = sync_inputs[2];

    input_synchronizer #(.WIDTH(5)) u_input_synchronizer (
        .clk_i(clk), .async_i(async_inputs), .sync_o(sync_inputs)
    );

    button_debouncer #(.STABLE_CYCLES(DEBOUNCE_CYCLES)) u_reset_debouncer (
        .clk_i(clk), .reset_i(power_on_reset), .button_i(sync_inputs[3]),
        .level_o(reset_level), .pressed_o(reset_pressed_unused)
    );

    button_debouncer #(.STABLE_CYCLES(DEBOUNCE_CYCLES)) u_ped_debouncer (
        .clk_i(clk), .reset_i(reset_level || power_on_reset),
        .button_i(sync_inputs[4]), .level_o(ped_level_unused),
        .pressed_o(ped_pressed)
    );

    tick_generator #(.CLOCK_HZ(CLOCK_HZ), .TICK_HZ(TIMER_TICK_HZ)) u_tick_generator (
        .clk_i(clk), .reset_i(reset_level || power_on_reset), .tick_o(timer_tick)
    );

    traffic_controller #(
        .STARTUP_TICKS(STARTUP_TICKS), .MIN_GREEN_TICKS(MIN_GREEN_TICKS),
        .MAX_GREEN_TICKS(MAX_GREEN_TICKS), .AMBER_TICKS(AMBER_TICKS),
        .ALL_RED_TICKS(ALL_RED_TICKS), .PED_WALK_TICKS(PED_WALK_TICKS),
        .PED_FLASH_TICKS(PED_FLASH_TICKS), .PED_CLEAR_TICKS(PED_CLEAR_TICKS)
    ) u_controller (
        .clk_i(clk), .reset_i(reset_level || power_on_reset), .tick_i(timer_tick),
        .ns_vehicle_i(ns_vehicle_sync), .ew_vehicle_i(ew_vehicle_sync),
        .ped_request_i(ped_pressed), .emergency_i(emergency_sync),
        .ns_red_o(ns_red), .ns_amber_o(ns_amber), .ns_green_o(ns_green),
        .ew_red_o(ew_red), .ew_amber_o(ew_amber), .ew_green_o(ew_green),
        .ped_walk_o(ped_walk), .ped_stop_o(ped_stop),
        .emergency_o(emergency_active), .ped_request_pending_o(ped_pending),
        .state_code_o(state_code), .state_elapsed_ticks_o(_unused_state_elapsed),
        .state_remaining_ticks_o(state_remaining)
    );

    // Display format SSrr: decimal state code followed by remaining ticks.
    always_comb begin
        if (state_remaining > 32'd99) display_remaining = 8'd99;
        else                          display_remaining = state_remaining[7:0];
        display_tens = 4'(display_remaining / 8'd10);
        display_ones = 4'(display_remaining % 8'd10);
        display_digits[15:12] = state_code / 10;
        display_digits[11:8]  = state_code % 10;
        display_digits[7:4]   = display_tens;
        display_digits[3:0]   = display_ones;
    end

    seven_segment_driver #(.CLOCK_HZ(CLOCK_HZ)) u_seven_segment_driver (
        .clk_i(clk), .reset_i(reset_level || power_on_reset),
        .digits_i(display_digits), .decimal_points_i(4'b0000),
        .seg_o(seg), .dp_o(dp), .an_o(an)
    );

    always_comb begin
        led = 16'b0;
        led[0] = ns_red;       led[1] = ns_amber;    led[2] = ns_green;
        led[3] = ew_red;       led[4] = ew_amber;    led[5] = ew_green;
        led[6] = ped_walk;     led[7] = ped_stop;    led[8] = ped_pending;
        led[9] = ns_vehicle_sync; led[10] = ew_vehicle_sync;
        led[11] = state_code[0]; led[12] = state_code[1];
        led[13] = state_code[2]; led[14] = state_code[3];
        led[15] = emergency_active;
    end

endmodule

`default_nettype wire
