`timescale 1ns/1ps
`default_nettype none

module input_synchronizer #(
    parameter int unsigned WIDTH = 1,
    parameter logic [WIDTH-1:0] RESET_VALUE = '0
) (
    input  wire logic                 clk_i,
    input  wire logic [WIDTH-1:0]     async_i,
    output logic [WIDTH-1:0]     sync_o
);
    // Artix-7 INIT values provide deterministic safe startup without introducing
    // an asynchronous reset onto the synchronizer chain.
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    logic [WIDTH-1:0] sync_ff1 = RESET_VALUE;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    logic [WIDTH-1:0] sync_ff2 = RESET_VALUE;

    always_ff @(posedge clk_i) begin
        sync_ff1 <= async_i;
        sync_ff2 <= sync_ff1;
    end

    assign sync_o = sync_ff2;
endmodule

`default_nettype wire
