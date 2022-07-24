`include "lib/defines.vh"
module Instbuffer(
    input wire clk,
    input wire rst,
    input wire flush,
    input [`STALLBUS_WD-1:0] stall,

    input wire [`BR_WD-1:0] br_bus,
    input wire issue_mode_i,                    
    input wire issue_i,         
    
    input wire [`SFbits_wire] inst_sram_rdata,
    input wire [`IF_TO_IB_WD-1:0] if_to_ib_bus,
 
    output wire [`IB_TO_ID_WD-1:0] ib_to_id_bus, 
    output wire stallreq_for_fifo
);


// IF to IB

    reg [`IF_TO_IB_WD-1:0] if_to_ib_bus_r;
  
    always @ (posedge clk) begin
        if (rst|flush) begin
            if_to_ib_bus_r <= `IF_TO_IB_WD'b0;
        end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_ib_bus_r <= `IF_TO_IB_WD'b0;//考虑stall
        end
        else if (stall[1]==`NoStop) begin
            if_to_ib_bus_r <= if_to_ib_bus;
        end
    end

    wire [`TTbits_wire] inst1_i, inst2_i;
    wire [`TTbits_wire] inst1_pc_i, inst2_pc_i;
    wire inst1_valid, inst2_valid;
      
    wire ce, discard_current_inst;
    wire [31:0] ib_pc, pc_idef;
    wire matched, inst1_matched, inst2_matched;
    reg [31:0] pc_to_match;
    reg match_pc_en;

    wire fifo_full;
    wire launched; 
    wire launch_mode;
    wire inst1_is_br,inst2_is_br;
    wire stop_pop;

    assign {discard_current_inst, ce, pc_idef, ib_pc} = if_to_ib_bus_r;

    always @(posedge clk) begin
        if (rst | flush) begin
            match_pc_en <= 1'b0;
            pc_to_match <= 32'b0;
        end
        else if(br_bus[32] & ~match_pc_en) begin
            pc_to_match <= br_bus[31:0];
        end
        else if(discard_current_inst & ~match_pc_en & (pc_to_match[1:0]==2'b0)) begin
            match_pc_en <= 1'b1;
        end
        else if(match_pc_en & matched) begin
            match_pc_en <= 1'b0;
            pc_to_match <= 32'b0;
        end
    end

    assign inst1_i = inst_sram_rdata[31: 0];
    assign inst2_i = inst_sram_rdata[63:32];

    assign inst1_pc_i = ib_pc;
    assign inst2_pc_i = inst1_valid ? ib_pc+32'd4 : pc_idef;

    assign inst1_matched = ~match_pc_en | (match_pc_en && inst1_pc_i==pc_to_match);
    assign inst2_matched = ~match_pc_en | (match_pc_en && inst2_pc_i==pc_to_match);
    assign matched = inst1_matched | inst2_matched;

    assign inst1_valid = ~ce                 ? 1'b0 :
                          ib_pc != pc_idef     ? 1'b0 :
                          discard_current_inst ? 1'b0 : 
                          ~inst1_matched       ? 1'b0 : 1'b1;
    assign inst2_valid = ~ce                 ? 1'b0 :
                          ib_pc == 32'b0       ? 1'b0 :
                          discard_current_inst ? 1'b0 : 
                          ~matched             ? 1'b0 : 1'b1;


// FIFO structure  

    reg [`InstBus] FIFO_data[`InstBufferSize-1:0]; // inst
    reg [`InstBus] FIFO_addr[`InstBufferSize-1:0]; // pc
	
    // ptr
    reg [`InstBufferSizeLog2-1:0] tail; 
    reg [`InstBufferSizeLog2-1:0] head; 
    reg [`InstBufferSize-1:0] FIFO_valid; // validation


// pop after launching

    always@(posedge clk)begin
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
	

// push inst
    always@(posedge clk)begin
        if(rst|flush)begin
            tail <= `InstBufferSizeLog2'h0;
        end
        else if(inst1_valid == `Valid && inst2_valid == `Invalid) begin
            FIFO_data[tail]  <= inst1_i;
            FIFO_addr[tail]  <= inst1_pc_i;
            FIFO_valid[tail] <= `Valid;
            tail <= tail + 1;
        end 
        else if(inst1_valid == `Invalid && inst2_valid == `Valid) begin
            FIFO_data[tail]  <= inst2_i;
            FIFO_addr[tail]  <= inst2_pc_i;
            FIFO_valid[tail] <= `Valid;
            tail <= tail + 1;
        end 
        else if(inst1_valid == `Valid && inst2_valid == `Valid) begin 
            FIFO_data[tail] <= inst1_i;
            FIFO_data[tail+`InstBufferSizeLog2'h1] <= inst2_i;
            FIFO_addr[tail] <= inst1_pc_i;
            FIFO_addr[tail+`InstBufferSizeLog2'h1] <= inst2_pc_i; 
            FIFO_valid[tail] <= `Valid;
            FIFO_valid[tail+`InstBufferSizeLog2'h1] <= `Valid;
            tail <= tail + 2;
        end
    end	


// output	

    wire [`TTbits_wire] inst1_o, inst2_o;
    wire [`TTbits_wire] inst1_pc_o, inst2_pc_o;
    wire inst1_valid_o, inst2_valid_o;

	assign inst1_o       = stall[2] & ~stall[3] ? `ZeroWord : FIFO_data[head]; 
	assign inst2_o       = stall[2] & ~stall[3] ? `ZeroWord : FIFO_data[head+`InstBufferSizeLog2'h1];
	assign inst1_pc_o    = stall[2] & ~stall[3] ? `ZeroWord : FIFO_addr[head];
	assign inst2_pc_o    = stall[2] & ~stall[3] ? `ZeroWord : FIFO_addr[head+`InstBufferSizeLog2'h1];
    assign inst1_valid_o = stall[2] ? 1'b0 : FIFO_valid[head];
    assign inst2_valid_o = stall[2] ? 1'b0 : FIFO_valid[head+`InstBufferSizeLog2'h1];

	assign buffer_full       = FIFO_valid[tail+`InstBufferSizeLog2'h5];
    assign stallreq_for_fifo = buffer_full & ~br_bus[32]; // 队满时要发射的如果恰好是跳转则不能stall 要让IF取址
    
    assign ib_to_id_bus = {
        inst2_valid_o,
        inst2_pc_o,
        inst2_o,
        inst1_valid_o,
        inst1_pc_o,
        inst1_o
    };


endmodule