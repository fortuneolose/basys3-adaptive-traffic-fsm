`timescale 1ns/1ps
`default_nettype none

module tick_generator #(
    parameter int unsigned CLOCK_HZ = 100_000_000,
    parameter int unsigned TICK_HZ  = 1
) (
    input  wire logic clk_i,
    input  wire logic reset_i,
    output logic tick_o
);
    localparam int unsigned CLKS_PER_TICK = CLOCK_HZ / TICK_HZ;
    localparam int unsigned COUNTER_WIDTH =
        (CLKS_PER_TICK <= 1) ? 1 : $clog2(CLKS_PER_TICK);
    localparam logic [COUNTER_WIDTH-1:0] TERMINAL_COUNT =
        COUNTER_WIDTH'(CLKS_PER_TICK - 1);

    logic [COUNTER_WIDTH-1:0] counter_q = '0;

`ifndef SYNTHESIS
    initial begin
        if ((CLOCK_HZ == 0) || (TICK_HZ == 0) ||
            ((CLOCK_HZ % TICK_HZ) != 0)) begin
            $fatal(1, "CLOCK_HZ must be a nonero integer multiple of TICK_HZ");
        end
    end
`endif

    always_ff @(posedge clk_i) begin
        tick_o <= 1'b0;
        if (reset_i) begin
            counter_q <= '0;
        end else if (counter_q == TERMINAL_COUNT) begin
            counter_q <= '0;
            tick_o    <= 1'b1;
        end else begin
            counter_q <= counter_q + 1'b1;
        end
    end
endmodule

`default_nettype wire
