`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/23/2021 03:43:57 PM
// Design Name: 
// Module Name: VotingBlk
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
`include "global.v"

module VotingBlk #(
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
    
    input wire        [$clog2(FM_SIZE**2)-1:0]  i_data_ref_addr, // reference is the value sequential position number
    input wire signed [`A_DSP_WIDTH-1:0]        i_data,
    input wire signed [`B_DSP_WIDTH-1:0]        i_weight,
    input wire signed [`OUTPUT_DSP_WIDTH-1:0]   i_partoutvalue, //  comes from B port, used for read and write
    input wire signed [`OUTPUT_DSP_WIDTH-1:0]   i_partoutvalue_b,   //  comes from A port, that is used just for write

    output reg  [$clog2(FM_SIZE**2):0]      o_nnvr_r_addr, // one more bit to test the end of process
    output reg  [$clog2(FM_SIZE**2):0]    o_ifm_r_addr,
    output reg  [$clog2(OUT_SIZE**2):0]   o_ofm_w_addr,
    output wire [$clog2(OUT_SIZE**2):0]   o_ofm_r_addr, // also used for writing process
    output reg  [$clog2(KERNEL_SIZE**2):0]  o_wght_r_addr, // one more bit to test the end of read process

    output reg  [$clog2(OUT_SIZE**2):0]   o_ref_w_addr,   //  registers to manage the output non-null values address
    output reg  [$clog2(OUT_SIZE**2):0]   o_ref_data,
    output reg  o_ref_w_en,
    
    output reg  [$clog2(OUT_SIZE**2):0]   o_values,

    output wire o_en,
    output wire o_en_b,
    output wire signed [`OUTPUT_DSP_WIDTH-1:0] o_data,
    output wire signed [`OUTPUT_DSP_WIDTH-1:0] o_data_b,
    
    output reg o_done
);

    assign o_en_b = 0;
    localparam [2:0]    s_idle          = 3'b000,
                        s_filter_load   = 3'b001,
                        s_process_data  = 3'b010,
                        s_done          = 3'b011;
                        
    reg [2:0] r_next_state;

    wire signed [`B_DSP_WIDTH-1:0]              w_weight;
    reg         [$clog2(KERNEL_SIZE**2)-1:0]    r_weight_cnt;
    reg         [$clog2(FM_SIZE**2)-1:0]        r_data_refaux_addr, r_last_d_addr;
    reg signed  [$clog2(FM_SIZE**2):0]          r_x, r_y;
    reg signed  [`B_DSP_WIDTH-1:0]              r_filter            [(KERNEL_SIZE**2)-1:0];
    reg         [$clog2(FM_SIZE**2)-1:0]        r_ref_d_addrs       [(KERNEL_SIZE**2)-1:0]; // addrs to process from the output
    reg         [$clog2(KERNEL_SIZE**2)-1:0]    r_ref_w_addrs       [(KERNEL_SIZE**2)-1:0]; // filter weights addrs for each process
    reg         [$clog2(KERNEL_SIZE**2):0]      r_process_cnt_hist, r_ref_index_it, r_ref_addrs_index;
    reg         [$clog2(KERNEL_SIZE**2)+1:0]    r_ref_index, r_val_it_cnt;

    reg r_detect_pos, r_PE_en, r_weight_en;
    
    assign w_weight     = r_ref_index_it == 0? r_filter[r_ref_w_addrs[0]]: r_filter[r_ref_w_addrs[r_ref_index_it - 1]];  
    assign o_ofm_r_addr = r_ref_d_addrs[r_ref_index_it];  // addr will be used also for the write operation


    /***************************************************
                    State machine
    ***************************************************/
    always @(posedge i_clk) begin
        if(i_rst) begin
            r_next_state <= s_idle;
        end
        else begin
            case(r_next_state)
                s_idle: begin
                    if(i_start) begin
                        r_next_state <= s_filter_load;
                    end
                    else begin
                        r_next_state <= s_idle;
                    end
                end
            
                s_filter_load: begin
                    if(o_wght_r_addr >= KERNEL_SIZE**2) begin
                        r_next_state <= s_process_data;
                    end
                    else begin 
                        r_next_state <= s_filter_load;
                    end
                
                end

                s_process_data: begin
                    if((o_nnvr_r_addr >= FMVALUES) && (r_ref_index_it >= r_ref_addrs_index)) begin
                        r_next_state <= s_done;
                    end
                    else begin
                        r_next_state <= s_process_data;
                    end
                end   

                s_done: begin
                    r_next_state <= s_done;
                end
            endcase
        end
    end  


    /***************************************************
                    Filter load state
    ***************************************************/
    always@(posedge i_clk) begin
        if(r_next_state == s_idle) begin
            o_wght_r_addr   <= 0;
            r_weight_en     <= 0;
            r_weight_cnt    <= KERNEL_SIZE**2 - 1;
        end
        else if(r_next_state == s_filter_load) begin
            if(o_wght_r_addr < KERNEL_SIZE**2)begin
                o_wght_r_addr   <= o_wght_r_addr + 1;
                r_weight_en     <= 1;
            end
            else
                r_weight_en     <= 0;
        end

        if(r_weight_en) begin
            r_filter[r_weight_cnt]  <= i_weight;
            r_weight_cnt            <= r_weight_cnt - 1;
        end
    end


    /***************************************************
                    Process state
    ***************************************************/

    /*  Input read control  */
    always@(posedge i_clk) begin
        if(r_next_state == s_idle) begin
            o_nnvr_r_addr       <= 0;
            o_ifm_r_addr        <= i_data_ref_addr;
            r_process_cnt_hist  <= 1;
        end
        else if((r_next_state == s_filter_load) && (o_wght_r_addr >= KERNEL_SIZE**2)) begin
            o_nnvr_r_addr   <= o_nnvr_r_addr + 1;
        end
        else if((r_next_state == s_process_data)) begin   // after shift being made
            if(r_ref_index_it == r_ref_addrs_index) begin                
                o_nnvr_r_addr   <= o_nnvr_r_addr + 1;
                o_ifm_r_addr    <= i_data_ref_addr;
                r_last_d_addr   <= o_ifm_r_addr;    // register the current non-null input value address

                if((r_process_cnt_hist == 0) && (r_ref_addrs_index != 0))   //  adjust input read position timing
                    o_ifm_r_addr    <= r_data_refaux_addr;

                r_process_cnt_hist <= r_ref_addrs_index;
            end
            else if((r_process_cnt_hist == 0) && (r_ref_addrs_index != 0) && (r_ref_index_it == 0)) begin
                o_nnvr_r_addr       <= o_nnvr_r_addr - 1;
                r_data_refaux_addr  <= i_data_ref_addr;
            end
            
        end
    end

    /*  Base PE control */
    always@(posedge i_clk) begin
        r_ref_index_it      <= 0;
        o_ofm_w_addr        <= r_ref_d_addrs[0];
        r_PE_en             <= 0;
        
        if((r_next_state == s_process_data)) begin  
            if (r_ref_index_it < r_ref_addrs_index)begin
                r_ref_index_it      <= r_ref_index_it + 1;
                o_ofm_w_addr        <= r_ref_d_addrs[r_ref_index_it];
                r_PE_en             <= 1;
            end
        end
    end

    
    /*  Detect positions control    */
    always@(posedge i_clk) begin
        r_detect_pos <= 0;
        if((r_next_state == s_filter_load) && (o_wght_r_addr >= KERNEL_SIZE**2)) begin
            r_detect_pos <= 1;  
        end
        else if((r_next_state == s_process_data) && (r_ref_index_it == r_ref_addrs_index)) begin   // after shift being made
            r_detect_pos <= 1;
        end
    end




  
    /*  Positions management   */
    always@(r_detect_pos) begin
        r_ref_addrs_index   = 0;

        for(r_ref_index = 0; r_ref_index <= KERNEL_SIZE**2 - 1; r_ref_index = r_ref_index + 1) begin    //   iteration for all the KERNEL_SIZE**2 values
            r_ref_d_addrs[r_ref_index]     = 0;   
            r_ref_w_addrs[r_ref_index]     = 0;    

            r_x = (o_ifm_r_addr / FM_SIZE + (KERNEL_SIZE/2)) - ((KERNEL_SIZE**2 - r_ref_index - 1) / KERNEL_SIZE); // using the IFM detect if output is available
            r_y = (o_ifm_r_addr % FM_SIZE + (KERNEL_SIZE/2)) - ((KERNEL_SIZE**2 - r_ref_index - 1) % KERNEL_SIZE);

            if(((r_x >= (KERNEL_SIZE/2) - PADDING) && (r_x <= FM_SIZE - (KERNEL_SIZE/2 +1) + PADDING) &&    // output boundaries
                (r_y >= (KERNEL_SIZE/2) - PADDING) && (r_y <= FM_SIZE - (KERNEL_SIZE/2 +1) + PADDING)) && 
                ((r_x - (KERNEL_SIZE/2) + PADDING) % STRIDE == 0) &&    // strided convolutions
                ((r_y - (KERNEL_SIZE/2) + PADDING) % STRIDE == 0) &&
                (r_filter[r_ref_index] != 0)) begin // null weights
                
                    r_ref_d_addrs[r_ref_addrs_index]    = ((r_x - (KERNEL_SIZE/2) + PADDING)/STRIDE) * OUT_SIZE + ((r_y - (KERNEL_SIZE/2) + PADDING)/STRIDE);     // addr of the values that will be read from outmem
                    r_ref_w_addrs[r_ref_addrs_index]    = r_ref_index;                          // addr of the filter weights that will be sent to PE
                    r_ref_addrs_index                   = r_ref_addrs_index + 1;                // how many values need to be read from outmem
            end
        end
    end

    /***************************************************
                    Done state
    ***************************************************/
    always@(posedge i_clk) begin
        if(r_next_state == s_idle) begin
            o_done  <= 0;
        end
        else if(r_next_state == s_done) begin
            o_done  <= 1;
        end
    end



    PE #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .FM_SIZE(FM_SIZE),
        .PADDING(PADDING),
        .STRIDE(STRIDE)
    )PE1(
        .i_clk(i_clk),
        .i_en(r_PE_en),
        .i_data(i_data), 
        .i_weight(w_weight),
        .i_partoutvalue(i_partoutvalue),

        .o_en(o_en),
        .o_data(o_data)
    );
endmodule
