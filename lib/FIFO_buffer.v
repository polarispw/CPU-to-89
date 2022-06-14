`include "defines.vh"
module Instbuffer(
    input clk,
    input rst,
    input flush,
    input [`StallBus-1:0] stall,

    //launch
    input  wire issue_mode_i,                     //issue mode of issue stage
    input  wire issue_i,                          //whether issue stage has issued inst
    output wire[`InstBus] issue_inst1_o,         //inst 
    output wire[`InstBus] issue_inst2_o,
    output wire[`InstAddrBus] issue_inst1_addr_o,//pc
    output wire[`InstAddrBus] issue_inst2_addr_o,
    output wire[32:0] issue_bpu_predict_info_o,
    output wire issue_inst1_valid_o,
    output wire issue_inst2_valid_o,
    output wire buffer_full_o,
    //inst
    input wire[`InstBus] ICache_inst1_i,
    input wire[`InstBus] ICache_inst2_i,
    input wire[`InstAddrBus] ICache_inst1_addr_i,
    input wire[`InstAddrBus] ICache_inst2_addr_i, 
    input wire ICache_inst1_valid_i,
    input wire ICache_inst2_valid_i,
    input wire only_delayslot_inst_i,
    input wire[32:0] bpu_predict_info_i,
    input wire bpu_select_i
);
    
    wire[32:0] issue_bpu_predict_info_o1;

    //队列本体 max volume=32 insts
    reg [`InstBus] FIFO_data[`InstBufferSize-1:0]; // inst
    reg [`InstBus] FIFO_addr[`InstBufferSize-1:0]; // pc
	
    //头尾指针维护
    reg [`InstBufferSizeLog2-1:0]tail; //当前正在写入的数据位置
    reg [`InstBufferSizeLog2-1:0]head; //当前读取指令的首位置
    reg [`InstBufferSize-1:0]FIFO_valid; //buffer中每个位置的数据是否有效（高电平有效）
    reg [`StallBus-1:0] stall_r;

    // pop after launching
    always@(posedge clk)begin
        stall_r <= stall;
        if(rst|flush)begin
            head <= `InstBufferSizeLog2'h0;
			FIFO_valid <= `InstBufferSize'h0;
        end
        else if( issue_i == `Valid && issue_mode_i == `SingleIssue )begin//pop one inst
            FIFO_valid[head] <= `Invalid;
			head <= head + 1;
		end
        else if( issue_i == `Valid && issue_mode_i == `DualIssue )begin//pop two inst
			FIFO_valid[head] <= `Invalid;
			FIFO_valid[head+`InstBufferSizeLog2'h1] <= `Invalid;
            head <= head + 2;
		end
    end
	
	// push back inst
    always@(posedge clk)begin
        if(rst|flush)begin
            tail <= `InstBufferSizeLog2'h0;
        end
        else if(ICache_inst1_valid_i == `Valid && ICache_inst2_valid_i == `Invalid) begin
            FIFO_data[tail] <= ICache_inst1_i;
            FIFO_addr[tail] <= ICache_inst1_addr_i; //bpu_select_i ? {ICache_inst1_addr_i,33'd0} : {ICache_inst1_addr_i,bpu_predict_info_i};
            FIFO_valid[tail] <= `Valid;
            tail <= tail + 1;
        end 
        else if(ICache_inst1_valid_i == `Invalid && ICache_inst2_valid_i == `Valid) begin
            FIFO_data[tail] <= ICache_inst2_i;
            FIFO_addr[tail] <= ICache_inst2_addr_i; //bpu_select_i ? {ICache_inst1_addr_i,33'd0} : {ICache_inst1_addr_i,bpu_predict_info_i};
            FIFO_valid[tail] <= `Valid;
            tail <= tail + 1;
        end 
        else if(ICache_inst1_valid_i == `Valid && ICache_inst2_valid_i == `Valid) begin 
            FIFO_data[tail] <= ICache_inst1_i;
            FIFO_data[tail+`InstBufferSizeLog2'h1] <= ICache_inst2_i;
            FIFO_addr[tail] <= ICache_inst1_addr_i; //bpu_select_i ? {ICache_inst1_addr_i,33'd0} : {ICache_inst1_addr_i,bpu_predict_info_i};
            FIFO_addr[tail+`InstBufferSizeLog2'h1] <= ICache_inst2_addr_i; //bpu_select_i ? {ICache_inst2_addr_i,bpu_predict_info_i} : {ICache_inst2_addr_i,33'd0};
            FIFO_valid[tail] <= `Valid;
            FIFO_valid[tail+`InstBufferSizeLog2'h1] <= `Valid;
            tail <= tail + 2;
        end
    end	
	   
//output	
	assign issue_inst1_o       = stall_r[2]&~stall_r[3] ? 32'b0 : FIFO_data[head]; 
	assign issue_inst2_o       = stall_r[2]&~stall_r[3] ? 32'b0 : FIFO_data[head+`InstBufferSizeLog2'h1];
	
	assign issue_inst1_addr_o  = stall_r[2]&~stall_r[3] ? 32'b0 : FIFO_addr[head];
	assign issue_inst2_addr_o  = stall_r[2]&~stall_r[3] ? 32'b0 : FIFO_addr[head+`InstBufferSizeLog2'h1];

    assign issue_inst1_valid_o = stall_r[2] ? 1'b0 : FIFO_valid[head];
    assign issue_inst2_valid_o = stall_r[2] ? 1'b0 : FIFO_valid[head+`InstBufferSizeLog2'h1];

	assign buffer_full_o       = FIFO_valid[tail+`InstBufferSizeLog2'h5];

endmodule