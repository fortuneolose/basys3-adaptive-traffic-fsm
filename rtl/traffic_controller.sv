`timescale 1ns/1ps
`default_nettype none

// Synchronous Moore FSM. All inputs to this block are expected to be synchronous
// to clk_i; the board wrapper performs synchronization and debouncing.
module traffic_controller #(
    parameter int unsigned STARTUP_TICKS   = 2,
    parameter int unsigned MIN_GREEN_TICKS = 8,
    parameter int unsigned MAX_GREEN_TICKS = 15,
    parameter int unsigned AMBER_TICKS     = 3,
    parameter int unsigned ALL_RED_TICKS   = 1,
    parameter int unsigned PED_WALK_TICKS  = 6,
    parameter int unsigned PED_FLASH_TICKS = 4,
    parameter int unsigned PED_CLEAR_TICKS = 1
) (
    input  wire logic        clk_i,
    input  wire logic        reset_i,
    input  wire logic        tick_i,
    input  wire logic        ns_vehicle_i,
    input  wire logic        ew_vehicle_i,
    input  wire logic        ped_request_i,
    input  wire logic        emergency_i,

    output logic        ns_red_o,
    output logic        ns_amber_o,
    output logic        ns_green_o,
    output logic        ew_red_o,
    output logic        ew_amber_o,
    output logic        ew_green_o,
    output logic        ped_walk_o,
    output logic        ped_stop_o,
    output logic        emergency_o,
    output logic        ped_request_pending_o,
    output logic [3:0]  state_code_o,
    output logic [31:0] state_elapsed_ticks_o,
    output logic [31:0] state_remaining_ticks_o
);

    typedef enum logic [3:0] {
        STARTUP_ALL_RED  = 4'd0,
        NS_GREEN         = 4'd1,
        NS_AMBER         = 4'd2,
        ALL_RED_TO_EW    = 4'd3,
        EW_GREEN         = 4'd4,
        EW_AMBER         = 4'd5,
        ALL_RED_TO_NS    = 4'd6,
        PED_WALK         = 4'd7,
        PED_FLASH        = 4'd8,
        PED_CLEAR        = 4'd9,
        EMERGENCY_ALL_RED = 4'd10
    } state_t;

    state_t state_q = STARTUP_ALL_RED;
    state_t state_d;
    logic emergency_latched_q = 1'b0;
    logic [31:0] state_duration_ticks;
    logic [31:0] elapsed_after_tick;

`ifndef SYNTHESIS
    initial begin
        if ((STARTUP_TICKS == 0) || (MIN_GREEN_TICKS == 0) ||
            (MAX_GREEN_TICKS < MIN_GREEN_TICKS) || (AMBER_TICKS == 0) ||
            (ALL_RED_TICKS == 0) || (PED_WALK_TICKS == 0) ||
            (PED_FLASH_TICKS == 0) || (PED_CLEAR_TICKS == 0)) begin
            $fatal(1, "Invalid traffic_controller timing parameter(s)");
        end
    end
`endif

    assign state_code_o = state_q;
    assign elapsed_after_tick = state_elapsed_ticks_o + 32'd1;

    // Emergency is sampled on every system-clock edge, independently of tick_i.
    // Once set, emergency_latched_q can only be cleared by reset after the input
    // has gone low.
    always_ff @(posedge clk_i) begin
        if (emergency_i) begin
            emergency_latched_q <= 1'b1;
        end else if (reset_i) begin
            emergency_latched_q <= 1'b0;
        end
    end

    // A pulse is remembered until the complete pedestrian phase has finished.
    // A new pulse coincident with completion wins, preserving the new request.
    always_ff @(posedge clk_i) begin
        if (reset_i && !emergency_i) begin
            ped_request_pending_o <= 1'b0;
        end else begin
            if (ped_request_i) begin
                ped_request_pending_o <= 1'b1;
            end
            if (tick_i && (state_q == PED_CLEAR) && (state_d == NS_GREEN)) begin
                ped_request_pending_o <= ped_request_i;
            end
        end
    end

    // State register and per-state elapsed-tick counter.
    always_ff @(posedge clk_i) begin
        if (emergency_i) begin
            state_q               <= EMERGENCY_ALL_RED;
            state_elapsed_ticks_o <= 32'd0;
        end else if (reset_i) begin
            state_q               <= STARTUP_ALL_RED;
            state_elapsed_ticks_o <= 32'd0;
        end else if (emergency_latched_q) begin
            state_q               <= EMERGENCY_ALL_RED;
            state_elapsed_ticks_o <= 32'd0;
        end else if (tick_i) begin
            if (state_d != state_q) begin
                state_q               <= state_d;
                state_elapsed_ticks_o <= 32'd0;
            end else begin
                state_elapsed_ticks_o <= state_elapsed_ticks_o + 32'd1;
            end
        end
    end

    // Next-state policy. Green phases leave at the minimum time when conflict
    // exists or active-direction demand has disappeared. They extend only while
    // active-direction traffic remains and no conflict waits, and never past max.
    always_comb begin
        state_d = state_q;

        case (state_q)
            STARTUP_ALL_RED: begin
                if (elapsed_after_tick >= STARTUP_TICKS) state_d = NS_GREEN;
            end

            NS_GREEN: begin
                if (elapsed_after_tick >= MAX_GREEN_TICKS) begin
                    state_d = NS_AMBER;
                end else if ((elapsed_after_tick >= MIN_GREEN_TICKS) &&
                             (ew_vehicle_i || ped_request_pending_o || !ns_vehicle_i)) begin
                    state_d = NS_AMBER;
                end
            end

            NS_AMBER: begin
                if (elapsed_after_tick >= AMBER_TICKS) state_d = ALL_RED_TO_EW;
            end

            ALL_RED_TO_EW: begin
                if (elapsed_after_tick >= ALL_RED_TICKS) state_d = EW_GREEN;
            end

            EW_GREEN: begin
                if (elapsed_after_tick >= MAX_GREEN_TICKS) begin
                    state_d = EW_AMBER;
                end else if ((elapsed_after_tick >= MIN_GREEN_TICKS) &&
                             (ns_vehicle_i || ped_request_pending_o || !ew_vehicle_i)) begin
                    state_d = EW_AMBER;
                end
            end

            EW_AMBER: begin
                if (elapsed_after_tick >= AMBER_TICKS) state_d = ALL_RED_TO_NS;
            end

            ALL_RED_TO_NS: begin
                if (elapsed_after_tick >= ALL_RED_TICKS) begin
                    if (ped_request_pending_o) state_d = PED_WALK;
                    else                       state_d = NS_GREEN;
                end
            end

            PED_WALK: begin
                if (elapsed_after_tick >= PED_WALK_TICKS) state_d = PED_FLASH;
            end

            PED_FLASH: begin
                if (elapsed_after_tick >= PED_FLASH_TICKS) state_d = PED_CLEAR;
            end

            PED_CLEAR: begin
                if (elapsed_after_tick >= PED_CLEAR_TICKS) state_d = NS_GREEN;
            end

            EMERGENCY_ALL_RED: state_d = EMERGENCY_ALL_RED;

            default: state_d = STARTUP_ALL_RED;
        endcase
    end

    // Moore outputs: defaults are fail-safe all-red. PED_FLASH alternates the
    // stop indication on tick boundaries while vehicle lamps remain red.
    always_comb begin
        ns_red_o     = 1'b1;
        ns_amber_o   = 1'b0;
        ns_green_o   = 1'b0;
        ew_red_o     = 1'b1;
        ew_amber_o   = 1'b0;
        ew_green_o   = 1'b0;
        ped_walk_o   = 1'b0;
        ped_stop_o   = 1'b1;
        emergency_o  = 1'b0;

        case (state_q)
            NS_GREEN: begin
                ns_red_o   = 1'b0;
                ns_green_o = 1'b1;
            end

            NS_AMBER: begin
                ns_red_o   = 1'b0;
                ns_amber_o = 1'b1;
            end

            EW_GREEN: begin
                ew_red_o   = 1'b0;
                ew_green_o = 1'b1;
            end

            EW_AMBER: begin
                ew_red_o   = 1'b0;
                ew_amber_o = 1'b1;
            end

            PED_WALK: begin
                ped_walk_o = 1'b1;
                ped_stop_o = 1'b0;
            end

            PED_FLASH: begin
                ped_stop_o = ~state_elapsed_ticks_o[0];
            end

            EMERGENCY_ALL_RED: emergency_o = 1'b1;

            STARTUP_ALL_RED,
            ALL_RED_TO_EW,
            ALL_RED_TO_NS,
            PED_CLEAR: begin
                // Safe defaults already describe these states.
            end

            default: begin
                // Invalid/unknown encodings retain fail-safe all-red outputs.
            end
        endcase
    end

    always_comb begin
        case (state_q)
            STARTUP_ALL_RED:   state_duration_ticks = STARTUP_TICKS;
            NS_GREEN,
            EW_GREEN:          state_duration_ticks = MAX_GREEN_TICKS;
            NS_AMBER,
            EW_AMBER:          state_duration_ticks = AMBER_TICKS;
            ALL_RED_TO_EW,
            ALL_RED_TO_NS:     state_duration_ticks = ALL_RED_TICKS;
            PED_WALK:          state_duration_ticks = PED_WALK_TICKS;
            PED_FLASH:         state_duration_ticks = PED_FLASH_TICKS;
            PED_CLEAR:         state_duration_ticks = PED_CLEAR_TICKS;
            default:           state_duration_ticks = 32'd0;
        endcase

        if (state_elapsed_ticks_o < state_duration_ticks) begin
            state_remaining_ticks_o = state_duration_ticks - state_elapsed_ticks_o;
        end else begin
            state_remaining_ticks_o = 32'd0;
        end
    end

endmodule

`default_nettype wire
