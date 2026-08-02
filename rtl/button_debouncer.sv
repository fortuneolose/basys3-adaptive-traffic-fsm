`timescale 1ns/1ps
`default_nettype none

module button_debouncer #(
    parameter int unsigned STABLE_CYCLES = 2_000_000
) (
    input  wire logic clk_i,
    input  wire logic reset_i,
    input  wire logic button_i,
    output logic level_o,
    output logic pressed_o
);
    localparam int unsigned COUNTER_WIDTH =
        (STABLE_CYCLES <= 1) ? 1 : $clog2(STABLE_CYCLES + 1);
    localparam logic [COUNTER_WIDTH-1:0] TERMINAL_COUNT =
        COUNTER_WIDTH'(STABLE_CYCLES - 1);

    logic [COUNTER_WIDTH-1:0] stable_count_q = '0;

`ifndef SYNTHESIS
    initial begin
        if (STABLE_CYCLES == 0) $fatal(1, "STABLE_CYCLES must be nonero");
    end
`endif

    always_ff @(posedge clk_i) begin
        pressed_o <= 1'b0;

        if (reset_i) begin
            stable_count_q <= '0;
            level_o        <= 1'b0;
        end else if (button_i == level_o) begin
            stable_count_q <= '0;
        end else if ((STABLE_CYCLES <= 1) ||
                     (stable_count_q == TERMINAL_COUNT)) begin
            stable_count_q <= '0;
            level_o        <= button_i;
            if (button_i) pressed_o <= 1'b1;
        end else begin
            stable_count_q <= stable_count_q + 1'b1;
        end
    end
endmodule

`default_nettype wire
