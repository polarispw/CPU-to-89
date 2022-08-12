`include "defines.vh"
module Instbuffer(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire stop_pop,
    input wire issue_i,      //whether inst launched
    input wire issue_mode_i, //issue mode
    // input wire [32:0] br_bus,

    input wire [`InstBus] inst1_i,
    input wire [`InstBus] inst2_i,
    input wire [`InstAddrBus] inst1_addr_i,
    input wire [`InstAddrBus] inst2_addr_i, 
    input wire inst1_valid_i,
    input wire inst2_valid_i,

    input  wire [`InstBus] current_pc,
    output wire [`InstBus] inst1_o,
    output wire [`InstBus] inst2_o,
    output wire [`InstAddrBus] inst1_addr_o, 
    output wire [`InstAddrBus] inst2_addr_o,
    output wire inst1_valid_o,
    output wire inst2_valid_o,
    // output wire br_pc_found,
    // output wire [31:0] br_target_addr, 
    output wire buffer_full_o
);

// fifo structure
    reg [`SFbits_wire] fifo_data[`FIFOLine-1:0]; // 高位(100)在左 低位(000)在右
    reg [26:0] tag_arry[`FIFOLine-1:0]; // 最左侧2bit是有效位
    reg [`FIFOSizebits-1:0] tail; // where to write
    reg [`FIFOSizebits-1:0] head; // where to read 

    wire [31:0] current_pc4 = current_pc + 4'h4;
    wire [24:0] tag_c, tag_c4;
    wire [3:0]  index_c, index_c4;
    wire [2:0]  offset_c, offset_c4;
    wire pc_hit, pc4_hit;

// write fifo
    always@(posedge clk)begin
        if(rst | flush)begin
            tail <= `FIFOSizebits'h0;
            head <= `FIFOSizebits'h0;
			tag_arry[ 0] <= `ZEROTAG;
            tag_arry[ 1] <= `ZEROTAG;
            tag_arry[ 2] <= `ZEROTAG;
            tag_arry[ 3] <= `ZEROTAG;
            tag_arry[ 4] <= `ZEROTAG;
            tag_arry[ 5] <= `ZEROTAG;
            tag_arry[ 6] <= `ZEROTAG;
            tag_arry[ 7] <= `ZEROTAG;
            tag_arry[ 8] <= `ZEROTAG;
            tag_arry[ 9] <= `ZEROTAG;
            tag_arry[10] <= `ZEROTAG;
            tag_arry[11] <= `ZEROTAG;
            tag_arry[12] <= `ZEROTAG;
            tag_arry[13] <= `ZEROTAG;
            tag_arry[14] <= `ZEROTAG;
            tag_arry[15] <= `ZEROTAG;
        end
        else if(inst1_valid_i == `Valid && inst2_valid_i == `Invalid) begin
            fifo_data[tail] <= {`ZeroWord, inst1_i};
            tag_arry[tail]  <= {2'b01, inst1_addr_i[31:7]};
            tail <= tail + 1;
		end
        else if(inst1_valid_i == `Invalid && inst2_valid_i == `Valid) begin
            fifo_data[tail] <= {inst2_i, `ZeroWord};
            tag_arry[tail]  <= {2'b10, inst1_addr_i[31:7]};
            tail <= tail + 1;
        end 
        else if(inst1_valid_i == `Valid && inst2_valid_i == `Valid) begin 
            fifo_data[tail] <= {inst2_i, inst1_i};
            tag_arry[tail]  <= {2'b11, inst1_addr_i[31:7]};
            tail <= tail + 2;
        end
        else begin

        end
        
        if(issue_i == `Valid && issue_mode_i == `SingleIssue) begin
            if(offset_c==3'b0) begin
                tag_arry[index_c][25] <= 1'b0;
            end
            else begin
                tag_arry[index_c][26] <= 1'b0;
            end
        end
        else if(issue_i == `Valid && issue_mode_i == `DualIssue) begin
            if(offset_c==3'b0) begin
                tag_arry[index_c][26:25] <= 2'b00;
            end
            else begin
                tag_arry[index_c ][26] <= 1'b0;
                tag_arry[index_c4][25] <= 1'b0;
            end
        end
        else begin

        end
    end


// get insts

    assign tag_c     = current_pc [31:7];
    assign index_c   = current_pc [ 6:3];
    assign offset_c  = current_pc [ 2:0];
    assign tag_c4    = current_pc4[31:7];
    assign index_c4  = current_pc4[ 6:3];
    assign offset_c4 = current_pc4[ 2:0];

    assign pc_hit  = (tag_arry[index_c ][24:0]==tag_c );
    assign pc4_hit = (tag_arry[index_c4][24:0]==tag_c4);

    assign inst1_o = offset_c[2]  ? {32{pc_hit} } & fifo_data[index_c ][`Highbits] : {32{pc_hit} } & fifo_data[index_c ][`Lowbits];
    assign inst2_o = offset_c4[2] ? {32{pc4_hit}} & fifo_data[index_c4][`Highbits] : {32{pc4_hit}} & fifo_data[index_c4][`Highbits];
    assign inst1_addr_o = current_pc;
    assign inst2_addr_o = current_pc+32'h4;
    assign inst1_valid_o = pc_hit  && ((offset_c[2] &tag_arry[index_c ][26])|(~offset_c[2] &tag_arry[index_c ][25]));
    assign inst2_valid_o = pc4_hit && ((offset_c4[2]&tag_arry[index_c4][26])|(~offset_c4[2]&tag_arry[index_c4][25]));

	assign buffer_full_o = tag_arry[tail+`FIFOSizebits'd2][26:25]!=2'b0;

endmodule