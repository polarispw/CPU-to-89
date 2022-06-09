`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`StallBus-1:0] stall,
   
    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,
    input wire [63:0] inst_sram_rdata,

    input wire [`EX_TO_RF_WD-1:0]  ex_to_rf_bus,
    input wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus,
    input wire [`WB_TO_RF_WD-1:0]  wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    output wire [`BR_WD-1:0] br_bus,
    output wire stallreq_for_load,
    output wire stallreq_for_cp0,
    output wire stallreq_for_bru,
    output wire stallreq_for_fifo
);

// process input data
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    reg flag;
    reg [63:0] buf_inst;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;   
            flag <= 1'b0;
            buf_inst <= 32'b0;
        end
        else if (flush) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            flag <= 1'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
            flag <= 1'b0;
        end
        else if (stall[1]==`Stop && stall[2]==`Stop && ~flag) begin
            flag <= 1'b1;
            buf_inst <= inst_sram_rdata;
        end
    end

// bypass and WB signal declare/init 
    wire ce;
    wire [31:0] id_pc;

    wire ex_rf_we, mem_rf_we, wb_rf_we;
    wire [4:0]  ex_rf_waddr, mem_rf_waddr, wb_rf_waddr;
    wire [31:0] ex_rf_wdata, mem_rf_wdata, wb_rf_wdata;

    wire ex_hi_we, mem_hi_we, wb_hi_we;
    wire ex_lo_we, mem_lo_we, wb_lo_we;
    wire [31:0] ex_hi_i, mem_hi_i, wb_hi_i;
    wire [31:0] ex_lo_i, mem_lo_i, wb_lo_i;

    wire last_inst_is_mfc0;

    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        last_inst_is_mfc0,
        ex_hi_we,
        ex_hi_i,
        ex_lo_we,
        ex_lo_i,
        ex_rf_we,
        ex_rf_waddr,
        ex_rf_wdata
    } = ex_to_rf_bus;
    assign {
        mem_hi_we,
        mem_hi_i,
        mem_lo_we,
        mem_lo_i,
        mem_rf_we,
        mem_rf_waddr,
        mem_rf_wdata
    } = mem_to_rf_bus;
    assign {
        wb_hi_we,
        wb_hi_i,
        wb_lo_we,
        wb_lo_i,
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;

// FIFO inst buffer
    wire [31:0] inst1_in;
    wire [31:0] inst2_in;
    wire [31:0] inst1_in_pc;
    wire [31:0] inst2_in_pc;
    wire inst1_in_val;
    wire inst2_in_val;

    wire [31:0] inst1;
    wire [31:0] inst2;
    wire [31:0] inst1_pc;
    wire [31:0] inst2_pc;
    wire able_to_launch;
    wire fifo_full;

    wire launched; 
    wire launch_mode;
    reg launch_r;

    assign inst1_in = ce ? flag ? buf_inst : inst_sram_rdata[31: 0] : 32'b0;
    assign inst2_in = ce ? flag ? buf_inst : inst_sram_rdata[63:32] : 32'b0;
    assign inst1_in_pc = id_pc;
    assign inst2_in_pc = id_pc+32'd4;
    assign inst1_in_val = 1'b1;
    assign inst2_in_val = 1'b1;

    Instbuffer FIFO_buffer(
        .clk                  (clk               ),
        .rst                  (rst               ),
        .flush                (flush             ),
        .issue_i              (launched          ),
        .issue_mode_i         (launch_mode       ),
        .ICache_inst1_i       (inst1_in          ),
        .ICache_inst2_i       (inst2_in          ),
        .ICache_inst1_addr_i  (inst1_in_pc       ),
        .ICache_inst2_addr_i  (inst2_in_pc       ),
        .ICache_inst1_valid_i (inst1_in_val      ),
        .ICache_inst2_valid_i (inst2_in_val      ),
        .only_delayslot_inst_i(inst1_in_delayslot),
        .issue_inst1_o        (inst1             ),
        .issue_inst2_o        (inst2             ),
        .issue_inst1_addr_o   (inst1_pc          ),
        .issue_inst2_addr_o   (inst2_pc          ),
        .issue_ok_o           (able_to_launch    ),
        .buffer_full_o        (fifo_full         )
    );


// decode & launch check
    wire [59:0] inst1_info, inst2_info;
    wire [32:0] br_bus1, br_bus2;
    wire [2:0] inst_flag1, inst_flag2;
    wire [4:0] rs_i1, rs_i2, rt_i1, rt_i2;

    assign rs_i1 = inst1[25:21];
    assign rt_i1 = inst1[20:16];
    assign rs_i2 = inst2[25:21];
    assign rt_i2 = inst2[20:16];

    wire data_corelate, inst_conflict;
    wire [2:0] sel_i1_src1, sel_i2_src1;
    wire [3:0] sel_i1_src2, sel_i2_src2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;

    decoder u1_decoder(
        .inst_sram_rdata  (inst1            ),
        .id_pc            (inst1_pc         ),
        .ce               (ce               ),
        .ex_rf_we         (ex_rf_we         ),
        .last_inst_is_mfc0(last_inst_is_mfc0),
        .ex_rf_waddr      (ex_rf_waddr      ),
        .inst_info        (inst1_info       ),
        .br_bus           (br_bus1          ),
        .stallreq_for_load(stallreq_for_load),
        .stallreq_for_cp0 (stallreq_for_cp0 ),
        .inst_flag        (inst_flag1       )
    );

    decoder u2_decoder(
        .inst_sram_rdata  (inst2            ),
        .id_pc            (inst2_pc         ),
        .ce               (ce               ),
        .ex_rf_we         (ex_rf_we         ),
        .last_inst_is_mfc0(last_inst_is_mfc0),
        .ex_rf_waddr      (ex_rf_waddr      ),
        .inst_info        (inst2_info       ),
        .br_bus           (br_bus2          ),
        .stallreq_for_load(stallreq_for_load),
        .stallreq_for_cp0 (stallreq_for_cp0 ),
        .inst_flag        (inst_flag2       )
    );

    assign sel_i1_src1 = inst1_info[15:13];
    assign sel_i2_src1 = inst2_info[15:13];
    assign sel_i1_src2 = inst1_info[12:9];
    assign sel_i2_src2 = inst2_info[12:9];
    assign rf_we_i1    = inst1_info[6];
    assign rf_we_i2    = inst2_info[6];
    assign rf_waddr_i1 = inst1_info[5:1];
    assign rf_waddr_i2 = inst2_info[5:1];

    assign data_corelate = (sel_i1_src1[0] & rf_we_i2 & (rf_waddr_i2==rs_i1)) | // i1 read reg[rs] & i2 write reg[rs]
                           (sel_i1_src2[0] & rf_we_i2 & (rf_waddr_i2==rt_i1)) | // i1 read reg[rt] & i2 write reg[rt]
                           (sel_i2_src1[0] & rf_we_i1 & (rf_waddr_i1==rs_i2)) | // i2 read reg[rs] & i1 write reg[rs]
                           (sel_i2_src2[0] & rf_we_i1 & (rf_waddr_i1==rt_i2)) ; // i2 read reg[rt] & i1 write reg[rt]

    assign inst_conflict = (inst_flag1[2:0]!=3'b0) && (inst_flag2[2:0]!=3'b0) ? 1'b1 : 1'b0;
    assign launch_mode = (data_corelate | inst_conflict) ? `SingleIssue : `DualIssue;
    assign launched = id_pc != 32'b0 ? 1'b1 : 1'b0;
    always@(posedge clk)begin
        if(rst|flush) begin
            launch_r <= 1'b0;
        end
        else begin
            launch_r <=launched;
        end
    end

    assign br_bus = br_bus1;

// operate regfile
    wire [31:0] rf_rdata1, rf_rdata2;
    wire [31:0] rdata1, rdata2;
    wire [31:0] hi_o, lo_o;
    wire [31:0] hi_rdata, lo_rdata;

    // IO
    regfile u_regfile(
    	.clk    (clk          ),
        .raddr1 (rs           ),
        .rdata1 (rf_rdata1    ),
        .raddr2 (rt           ),
        .rdata2 (rf_rdata2    ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );
    // bypass corelation
    assign rdata1 = (ex_rf_we  & (ex_rf_waddr == rs))  ? ex_rf_wdata  :
                    (mem_rf_we & (mem_rf_waddr == rs)) ? mem_rf_wdata :
                    (wb_rf_we  & (wb_rf_waddr == rs))  ? wb_rf_wdata  :  rf_rdata1;
    assign rdata2 = (ex_rf_we  & (ex_rf_waddr == rt))  ? ex_rf_wdata  :
                    (mem_rf_we & (mem_rf_waddr == rt)) ? mem_rf_wdata :
                    (wb_rf_we  & (wb_rf_waddr == rt))  ? wb_rf_wdata  :  rf_rdata2;

    hilo_reg u_hilo_reg(
    	.clk   (clk      ),
        .rst   (rst      ),
        .hi_we (wb_hi_we ),
        .hi_i  (wb_hi_i  ),
        .lo_we (wb_lo_we ),
        .lo_i  (wb_lo_i  ),
        .hi_o  (hi_o     ),
        .lo_o  (lo_o     )
    );

    assign hi_rdata = ex_hi_we  ? ex_hi_i  :
                      mem_hi_we ? mem_hi_i :
                      wb_hi_we  ? wb_hi_i  : hi_o;
    assign lo_rdata = ex_lo_we  ? ex_lo_i  :
                      mem_lo_we ? mem_lo_i :
                      wb_lo_we  ? wb_lo_i  : lo_o;


// output
    assign id_to_ex_bus = {
        inst2_pc,
        inst2,
        inst1_pc,
        inst1
    };

endmodule