`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2021 12:09:49 PM
// Design Name: 
// Module Name: top
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


module top #(
    parameter   KERNEL_SIZE = `KERNEL_SIZE,
    parameter   FM_SIZE     = `FM_SIZE,
    parameter   PADDING     = `PADDING,
    parameter   STRIDE      = `STRIDE,
    parameter   FMVALUES    = `FMVALUES,
    localparam  OUT_SIZE    = ((FM_SIZE - KERNEL_SIZE + 2 * PADDING) / STRIDE) + 1
)(
    input wire i_clk,
    input wire i_rst,
    input wire i_start,
    

    output wire  [$clog2(OUT_SIZE**2):0]   o_values,

    output wire o_en,
    //output wire o_en_b,
    output wire signed [`OUTPUT_DSP_WIDTH-1:0] o_data,
    //output wire signed [`OUTPUT_DSP_WIDTH-1:0] o_data_b,
    output wire o_done
);

    /*  IFM non-null values reference - BETA */
    wire [$clog2(FM_SIZE**2):0]   w_nnvr_r_addr;
    wire [$clog2(FM_SIZE**2):0]     w_nnvr_o_data;

    /*  IFM bram auxiliar registers  */
    wire [$clog2(FM_SIZE**2):0]   w_ifm_r_addr;
    wire signed [30-1:0]            w_ifm_o_data;

    /*  OFM bram auxiliar registers  */
    wire [$clog2(OUT_SIZE**2):0]        w_ofm_w_addr;
    wire [$clog2(OUT_SIZE**2):0]        w_ofm_r_addr;
    wire signed [`OUTPUT_DSP_WIDTH-1:0] w_ofm_i_data, w_ofm_i_data_b;
    wire signed [`OUTPUT_DSP_WIDTH-1:0] w_ofm_o_data, w_ofm_o_data_b;
    wire                                w_ofm_w_en, w_ofm_w_en_b;

    /*  OFM ref bram auxiliar registers  */
    wire    [$clog2(OUT_SIZE**2):0]  w_ref_w_addr;
    wire    [$clog2(OUT_SIZE**2):0]  w_ref_d_val_a;
    wire    w_ref_w_en;

    /*  WEIGHTS bram auxiliar registers  */
    wire [$clog2(KERNEL_SIZE**2):0]     w_wght_r_addr;
    wire signed [18-1:0]                w_wght_o_data;

    /*  output assign  */
    assign o_en = w_ofm_w_en;
    assign o_data = w_ofm_i_data;




    VotingBlk #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .FM_SIZE(FM_SIZE),
        .PADDING(PADDING),
        .STRIDE(STRIDE),
        .FMVALUES(FMVALUES)
    )uut(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(i_start),
        
        .i_data_ref_addr(w_nnvr_o_data), 
        .i_data(w_ifm_o_data), 
        .i_weight(w_wght_o_data),
        .i_partoutvalue(w_ofm_o_data_b),
        .i_partoutvalue_b(w_ofm_o_data),// mixed because b port is for read

        .o_nnvr_r_addr(w_nnvr_r_addr),
        .o_ifm_r_addr(w_ifm_r_addr),
        .o_ofm_w_addr(w_ofm_w_addr),
        .o_ofm_r_addr(w_ofm_r_addr),//also used to the write operation
        .o_wght_r_addr(w_wght_r_addr), 

        .o_ref_w_addr(w_ref_w_addr),
        .o_ref_data(w_ref_d_val_a),
        .o_ref_w_en(w_ref_w_en),

        .o_values(o_values),

        .o_en(w_ofm_w_en),
        .o_en_b(w_ofm_w_en_b),//
        .o_data(w_ofm_i_data),
        .o_data_b(w_ofm_i_data_b),//
        
        .o_done(o_done)
    );
    
    blk_mem_gen_ifm ifm_blckmem (
        .clka(i_clk),           // input wire clka
        .wea(r_ifm_w_en),       // input wire [0 : 0] wea
        .addra(w_ifm_r_addr),   // input wire [3 : 0] addra
        .dina(r_ifm_i_data),    // input wire [29 : 0] dina
        .douta(w_ifm_o_data)    // output wire [29 : 0] douta
    );

    blk_mem_gen_weight weight_blckmem (
        .clka(i_clk),           // input wire clka
        .wea(r_wght_w_en),      // input wire [0 : 0] wea
        .addra(w_wght_r_addr),  // input wire [3 : 0] addra
        .dina(r_wght_i_data),   // input wire [17 : 0] dina
        .douta(w_wght_o_data)   // output wire [17 : 0] douta
    );

    blk_mem_gen_valsref valsref_blckmem (
        .clka(i_clk),           // input wire clka
        .wea(r_nnvr_w_en),      // input wire [0 : 0] wea
        .addra(w_nnvr_r_addr),  // input wire [3 : 0] addra
        .dina(r_nnvr_i_data),   // input wire [29 : 0] dina
        .douta(w_nnvr_o_data)   // output wire [29 : 0] douta
    );

    blk_mem_gen_ofm ofm_blckmem (
        .clka(i_clk),               // input wire clka
        .wea(w_ofm_w_en),           // input wire [0 : 0] wea
        .addra(w_ofm_w_addr),       // input wire [1 : 0] addra
        .dina(w_ofm_i_data),        // input wire [47 : 0] dina
        .douta(w_ofm_o_data),       // output wire [47 : 0] douta
        .clkb(i_clk),               // input wire clkb
        .web(w_ofm_w_en_b),         // input wire [0 : 0] web
        .addrb(w_ofm_r_addr),       // input wire [1 : 0] addrb
        .dinb(w_ofm_i_data_b),      // input wire [47 : 0] dinb
        .doutb(w_ofm_o_data_b)      // output wire [47 : 0] doutb
    );

    blk_mem_gen_ofmref ofmref_blckmem (
        .clka(i_clk),           // input wire clka
        .wea(w_ref_w_en),       // input wire [0 : 0] wea
        .addra(w_ref_w_addr),   // input wire [1 : 0] addra
        .dina(w_ref_d_val_a),   // input wire [2 : 0] dina
        .douta(douta)           // output wire [2 : 0] douta
    );
    
endmodule
