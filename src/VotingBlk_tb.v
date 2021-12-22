`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/23/2021 03:46:12 PM
// Design Name: 
// Module Name: VotingBlk_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module VotingBlk_tb #(
    parameter   KERNEL_SIZE = 3,
    parameter   FM_SIZE     = 4,
    parameter   PADDING     = 0,
    parameter   STRIDE      = 1,
    parameter   FMVALUES    = 16, 
    localparam  OUT_SIZE    = ((FM_SIZE - KERNEL_SIZE + 2 * PADDING) / STRIDE) + 1
)();

    reg r_clk, r_rst, r_start;
    wire [$clog2(OUT_SIZE**2):0] w_o_values;
    wire signed [48-1:0] w_data;
    wire w_done, w_en;

    always @(posedge r_clk) begin
        if(w_done) begin
            $finish;
        end
    end
    

    initial begin
        r_clk   = 0;
        r_rst   = 1;
        r_start = 0;

        #150
        r_rst   <= 0;
        r_start <= 1;

        #10
        r_start <= 0;
    end

    always #5 r_clk = ~r_clk;


    top #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .FM_SIZE(FM_SIZE),
        .PADDING(PADDING),
        .STRIDE(STRIDE),
        .FMVALUES(FMVALUES)
    )uut(
        .i_clk(r_clk),
        .i_rst(r_rst),
        .i_start(r_start),
        

        .o_values(w_o_values),
        .o_en(w_en),
        .o_data(w_data),
        .o_done(w_done)
    );

endmodule