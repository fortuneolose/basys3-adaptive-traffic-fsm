`timescale 1ns/1ps
`default_nettype none

module seven_segment_driver #(
    parameter int unsigned CLOCK_HZ   = 100_000_000,
    parameter int unsigned DIGIT_HZ   = 1_000
) (
    input  wire logic        clk_i,
    input  wire logic        reset_i,
    input  wire logic [15:0] digits_i,
    input  wire logic [3:0]  decimal_points_i,
    output logic [6:0]  seg_o,
    output logic        dp_o,
    output logic [3:0]  an_o
);
    localparam int unsigned SCAN_HZ = DIGIT_HZ * 4;
    localparam int unsigned CLKS_PER_SCAN = CLOCK_HZ / SCAN_HZ;
    localparam int unsigned COUNTER_WIDTH =
        (CLKS_PER_SCAN <= 1) ? 1 : $clog2(CLKS_PER_SCAN);
    localparam logic [COUNTER_WIDTH-1:0] TERMINAL_COUNT =
        COUNTER_WIDTH'(CLKS_PER_SCAN - 1);

    logic [COUNTER_WIDTH-1:0] scan_counter_q = '0;
    logic [1:0] digit_select_q = 2'd0;
    logic [3:0] selected_digit;

`ifndef SYNTHESIS
    initial begin
        if ((SCAN_HZ == 0) || ((CLOCK_HZ % SCAN_HZ) != 0)) begin
            $fatal(1, "CLOCK_HZ must be an integer multiple of 4*DIGIT_HZ");
        end
    end
`endif

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            scan_counter_q <= '0;
            digit_select_q <= 2'd0;
        end else if (scan_counter_q == TERMINAL_COUNT) begin
            scan_counter_q <= '0;
            digit_select_q <= digit_select_q + 2'd1;
        end else begin
            scan_counter_q <= scan_counter_q + 1'b1;
        end
    end

    always_comb begin
        an_o = 4'b1111;
        case (digit_select_q)
            2'd0: begin an_o = 4'b1110; selected_digit = digits_i[3:0];   end
            2'd1: begin an_o = 4'b1101; selected_digit = digits_i[7:4];   end
            2'd2: begin an_o = 4'b1011; selected_digit = digits_i[11:8];  end
            default: begin an_o = 4'b0111; selected_digit = digits_i[15:12]; end
        endcase

        dp_o = ~decimal_points_i[digit_select_q];

        // Basys 3 segments are active low; bit order is {g,f,e,d,c,b,a}.
        case (selected_digit)
            4'h0: seg_o = 7'b1000000;
            4'h1: seg_o = 7'b1111001;
            4'h2: seg_o = 7'b0100100;
            4'h3: seg_o = 7'b0110000;
            4'h4: seg_o = 7'b0011001;
            4'h5: seg_o = 7'b0010010;
            4'h6: seg_o = 7'b0000010;
            4'h7: seg_o = 7'b1111000;
            4'h8: seg_o = 7'b0000000;
            4'h9: seg_o = 7'b0010000;
            4'hA: seg_o = 7'b0001000;
            4'hB: seg_o = 7'b0000011;
            4'hC: seg_o = 7'b1000110;
            4'hD: seg_o = 7'b0100001;
            4'hE: seg_o = 7'b0000110;
            default: seg_o = 7'b0001110;
        endcase
    end
endmodule

`default_nettype wire
