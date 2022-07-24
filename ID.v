`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,
   
    input wire [`IB_TO_ID_WD-1:0] ib_to_id_bus,

    input wire [`EX_TO_RF_WD-1:0]  ex_to_rf_bus,
    input wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus,
    input wire [`WB_TO_RF_WD-1:0]  wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    output wire [`BR_WD-1:0] br_bus,
    output wire launched,
    output wire launch_mode,
    output wire stallreq_for_load,
    output wire stallreq_for_cp0
);


// IB to ID

    reg [`IB_TO_ID_WD-1:0] ib_to_id_bus_r;
  
    always @ (posedge clk) begin
        if (rst |flush) begin
            ib_to_id_bus_r <= `IB_TO_ID_WD'b0;
        end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            ib_to_id_bus_r <= `IB_TO_ID_WD'b0;//考虑stall
        end
        else if (stall[2]==`NoStop) begin
            ib_to_id_bus_r <= ib_to_id_bus;
        end
    end

    wire [31:0] inst1, inst2;
    wire [31:0] inst1_pc, inst2_pc;
    wire inst1_valid, inst2_valid;

    assign {
        inst2_valid,
        inst2_pc,
        inst2,
        inst1_valid,
        inst1_pc,
        inst1
    } = ib_to_id_bus_r;


// bypass and WB signal

    wire ex_rf_we_i1, mem_rf_we_i1, wb_rf_we_i1;
    wire ex_rf_we_i2, mem_rf_we_i2, wb_rf_we_i2;
    wire [4:0]  ex_rf_waddr_i1, mem_rf_waddr_i1, wb_rf_waddr_i1;
    wire [4:0]  ex_rf_waddr_i2, mem_rf_waddr_i2, wb_rf_waddr_i2;
    wire [31:0] ex_rf_wdata_i1, mem_rf_wdata_i1, wb_rf_wdata_i1;
    wire [31:0] ex_rf_wdata_i2, mem_rf_wdata_i2, wb_rf_wdata_i2;

    wire ex_hi_we_i1, mem_hi_we_i1, wb_hi_we_i1;
    wire ex_hi_we_i2, mem_hi_we_i2, wb_hi_we_i2;
    wire ex_lo_we_i1, mem_lo_we_i1, wb_lo_we_i1;
    wire ex_lo_we_i2, mem_lo_we_i2, wb_lo_we_i2;
    wire [31:0] ex_hi_i1_i, mem_hi_i1_i, wb_hi_i1_i;
    wire [31:0] ex_hi_i2_i, mem_hi_i2_i, wb_hi_i2_i;
    wire [31:0] ex_lo_i1_i, mem_lo_i1_i, wb_lo_i1_i;
    wire [31:0] ex_lo_i2_i, mem_lo_i2_i, wb_lo_i2_i;

    wire last_inst_is_mfc0_i1, last_inst_is_mfc0_i2;
    
    assign {
        last_inst_is_mfc0_i2,
        ex_hi_we_i2,
        ex_hi_i2_i,
        ex_lo_we_i2,
        ex_lo_i2_i,
        ex_rf_we_i2,
        ex_rf_waddr_i2,
        ex_rf_wdata_i2,
        last_inst_is_mfc0_i1,
        ex_hi_we_i1,
        ex_hi_i1_i,
        ex_lo_we_i1,
        ex_lo_i1_i,
        ex_rf_we_i1,
        ex_rf_waddr_i1,
        ex_rf_wdata_i1
    } = ex_to_rf_bus;
    assign {
        mem_hi_we_i2,
        mem_hi_i2_i,
        mem_lo_we_i2,
        mem_lo_i2_i,
        mem_rf_we_i2,
        mem_rf_waddr_i2,
        mem_rf_wdata_i2,
        mem_hi_we_i1,
        mem_hi_i1_i,
        mem_lo_we_i1,
        mem_lo_i1_i,
        mem_rf_we_i1,
        mem_rf_waddr_i1,
        mem_rf_wdata_i1
    } = mem_to_rf_bus;
    assign {
        wb_hi_we_i2,
        wb_hi_i2_i,
        wb_lo_we_i2,
        wb_lo_i2_i,
        wb_rf_we_i2,
        wb_rf_waddr_i2,
        wb_rf_wdata_i2,
        wb_hi_we_i1,
        wb_hi_i1_i,
        wb_lo_we_i1,
        wb_lo_i1_i,
        wb_rf_we_i1,
        wb_rf_waddr_i1,
        wb_rf_wdata_i1
    } = wb_to_rf_bus;


// decode instructions

    wire [87:0] inst1_info_o, inst2_info_o;
    wire [87:0] inst1_info, inst2_info;
    wire [2:0] inst_flag1, inst_flag2;
    wire [4:0] rs_i1, rs_i2, rt_i1, rt_i2;
    wire stallreq_for_cp0_i1, stallreq_for_cp0_i2;
    wire stallreq_for_load_i1, stallreq_for_load_i2;

    assign rs_i1 = inst1[25:21];
    assign rt_i1 = inst1[20:16];
    assign rs_i2 = inst2[25:21];
    assign rt_i2 = inst2[20:16];

    wire data_corelate, inst_conflict;

    wire [2:0] sel_i1_src1, sel_i2_src1;
    wire [3:0] sel_i1_src2, sel_i2_src2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;

    wire [31:0] rf_rdata1_i1, rf_rdata2_i1;
    wire [31:0] rf_rdata1_i2, rf_rdata2_i2;
    wire [31:0] rdata1_i1, rdata2_i1;
    wire [31:0] rdata1_i2, rdata2_i2;
    
    wire [31:0] hi_o, lo_o;
    wire [31:0] hi_rdata, lo_rdata; 
    wire [32:0] br_bus1, br_bus2;

    decoder u1_decoder(
        .inst_sram_rdata  (inst1               ),
        .rdata1           (rdata1_i1           ),  
        .rdata2           (rdata2_i1           ), 
        .id_pc            (inst1_pc            ),
        .ex_rf_we         (ex_rf_we_i1         ),
        .ex_rf_waddr      (ex_rf_waddr_i1      ),
        .last_inst_is_mfc0(last_inst_is_mfc0_i1),
        .inst_info        (inst1_info_o        ),
        .br_bus           (br_bus1             ),
        .next_is_delayslot(inst1_is_br         ),
        .stallreq_for_load(stallreq_for_load_i1),
        .stallreq_for_cp0 (stallreq_for_cp0_i1 ),
        .inst_flag        (inst_flag1          )
    );

    decoder u2_decoder(
        .inst_sram_rdata  (inst2               ),
        .rdata1           (rdata1_i2           ),  
        .rdata2           (rdata2_i2           ),
        .id_pc            (inst2_pc            ),
        .ex_rf_we         (ex_rf_we_i1         ),
        .ex_rf_waddr      (ex_rf_waddr_i1      ),
        .last_inst_is_mfc0(last_inst_is_mfc0_i1),
        .inst_info        (inst2_info_o        ),
        .br_bus           (br_bus2             ),
        .next_is_delayslot(inst2_is_br         ),
        .stallreq_for_load(stallreq_for_load_i2),
        .stallreq_for_cp0 (stallreq_for_cp0_i2 ),
        .inst_flag        (inst_flag2          )
    );

    reg pre_is_br;//控制单发射时的延迟槽

    always @(posedge clk) begin
        if(rst | flush | ~inst1_is_br) begin
            pre_is_br <= 1'b0;
        end
        else if(inst1_is_br & launch_mode==`SingleIssue) begin
            pre_is_br <= 1'b1;
        end
    end

    assign stallreq_for_load = stallreq_for_load_i1;
    assign stallreq_for_cp0  = stallreq_for_cp0_i1 | stallreq_for_cp0_i2;
    
    assign inst1_info = pre_is_br   ? {1'b1, inst1_info_o[86:0]} : inst1_info_o;
    assign inst2_info = inst1_is_br ? {1'b1, inst2_info_o[86:0]} : inst2_info_o;


// operate regfile
    // RW
    regfile u_regfile(
    	.clk       (clk             ),
        .we_i1     (wb_rf_we_i1     ),
        .we_i2     (wb_rf_we_i2     ),
        .waddr_i1  (wb_rf_waddr_i1  ),
        .waddr_i2  (wb_rf_waddr_i2  ),
        .wdata_i1  (wb_rf_wdata_i1  ),
        .wdata_i2  (wb_rf_wdata_i2  ),
        .raddr1_i1 (rs_i1           ),
        .raddr2_i1 (rt_i1           ),
        .raddr1_i2 (rs_i2           ),
        .raddr2_i2 (rt_i2           ),
        .rdata1_i1 (rf_rdata1_i1    ),
        .rdata2_i1 (rf_rdata2_i1    ),
        .rdata1_i2 (rf_rdata1_i2    ),
        .rdata2_i2 (rf_rdata2_i2    )
    );

    hilo_reg u_hilo_reg(
    	.clk     (clk        ),
        .rst     (rst        ),
        .hi_we_i1(wb_hi_we_i1),
        .lo_we_i1(wb_lo_we_i1),
        .hi_we_i2(wb_hi_we_i2),
        .lo_we_i2(wb_lo_we_i2),
        .hi_i_i1 (wb_hi_i1_i ),
        .lo_i_i1 (wb_lo_i1_i ),
        .hi_i_i2 (wb_hi_i2_i ),
        .lo_i_i2 (wb_lo_i2_i ),
        .hi_o    (hi_o       ),
        .lo_o    (lo_o       )
    );

    // bypass corelation
    assign rdata1_i1 = (ex_rf_we_i1  & (ex_rf_waddr_i1  == rs_i1)) ? ex_rf_wdata_i1  :
                       (ex_rf_we_i2  & (ex_rf_waddr_i2  == rs_i1)) ? ex_rf_wdata_i2  :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rs_i1)) ? mem_rf_wdata_i1 :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rs_i1)) ? mem_rf_wdata_i2 :
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rs_i1)) ? wb_rf_wdata_i1  : 
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rs_i1)) ? wb_rf_wdata_i2  : rf_rdata1_i1;

    assign rdata2_i1 = (ex_rf_we_i1  & (ex_rf_waddr_i1  == rt_i1)) ? ex_rf_wdata_i1  :
                       (ex_rf_we_i2  & (ex_rf_waddr_i2  == rt_i1)) ? ex_rf_wdata_i2  :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rt_i1)) ? mem_rf_wdata_i1 :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rt_i1)) ? mem_rf_wdata_i2 :
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rt_i1)) ? wb_rf_wdata_i1  : 
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rt_i1)) ? wb_rf_wdata_i2  : rf_rdata2_i1;

    assign rdata1_i2 = (ex_rf_we_i1  & (ex_rf_waddr_i1  == rs_i2)) ? ex_rf_wdata_i1  :
                       (ex_rf_we_i2  & (ex_rf_waddr_i2  == rs_i2)) ? ex_rf_wdata_i2  :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rs_i2)) ? mem_rf_wdata_i1 :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rs_i2)) ? mem_rf_wdata_i2 :
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rs_i2)) ? wb_rf_wdata_i1  : 
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rs_i2)) ? wb_rf_wdata_i2  : rf_rdata1_i2;

    assign rdata2_i2 = (ex_rf_we_i1  & (ex_rf_waddr_i1  == rt_i2)) ? ex_rf_wdata_i1  :
                       (ex_rf_we_i2  & (ex_rf_waddr_i2  == rt_i2)) ? ex_rf_wdata_i2  :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rt_i2)) ? mem_rf_wdata_i1 :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rt_i2)) ? mem_rf_wdata_i2 :
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rt_i2)) ? wb_rf_wdata_i1  :
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rt_i2)) ? wb_rf_wdata_i2  : rf_rdata2_i2;

    assign hi_rdata = ex_hi_we_i1  ? ex_hi_i1_i  :
                      ex_hi_we_i2  ? ex_hi_i2_i  :
                      mem_hi_we_i1 ? mem_hi_i1_i :
                      mem_hi_we_i2 ? mem_hi_i2_i :
                      wb_hi_we_i1  ? wb_hi_i1_i  : 
                      wb_hi_we_i2  ? wb_hi_i2_i  : hi_o;

    assign lo_rdata = ex_lo_we_i1  ? ex_lo_i1_i  :
                      ex_lo_we_i2  ? ex_lo_i2_i  :
                      mem_lo_we_i1 ? mem_lo_i1_i :
                      mem_lo_we_i2 ? mem_lo_i2_i :
                      wb_lo_we_i1  ? wb_lo_i1_i  :
                      wb_lo_we_i2  ? wb_lo_i2_i  : lo_o;


// launch check

    wire inst1_launch = inst1_valid & ~stallreq_for_cp0;
    wire inst2_launch = inst2_valid & ~stallreq_for_cp0 & (launch_mode == `DualIssue);

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
    assign inst_conflict = (inst_flag1[2:0]!=3'b0) || (inst_flag2[2:0]!=3'b0) ? 1'b1 : 1'b0;

    assign launch_mode   = br_bus1[32]   ? `DualIssue   :
                           data_corelate ? `SingleIssue : 
                           inst_conflict ? `SingleIssue : 
                           inst2_is_br   ? `SingleIssue :
                           ~inst2_valid  ? `SingleIssue : `DualIssue;    

    assign launched      = (inst1_valid | inst2_valid) & ~stallreq_for_cp0 & ~stall[2];

    // always@(*)begin
    //     if(rst | flush) begin
    //         launch_r <= 1'b0;
    //     end
    //     else begin
    //         launch_r <= launched;
    //     end
    // end

    // assign stop_pop = (stall[2]) | inst1_info[28] | inst1_info[29];// stall或发射除法后不再弹出


// output part

    wire [`ID_INST_INFO-1:0] inst1_bus, inst2_bus;
    wire switch;
    
    assign br_bus = (br_bus1[32] & inst1_launch) ? br_bus1[32:0] : 33'b0 ;
    assign switch = br_bus[32];

    assign inst1_bus = inst1_launch ?
    {
        inst1_info[87:28],// 251:220
        hi_rdata,         // 219:188
        lo_rdata,         // 187:156
        inst1_pc,         // 155:124
        inst1,            // 123:92
        inst1_info[27:0], // 91:64
        rdata2_i1,        // 63:32
        rdata1_i1         // 31:0
    } : {124'b0,inst1_pc,124'b0};

    assign inst2_bus = inst2_launch ?
    {
        inst2_info[87:28],// 279:220
        hi_rdata,         // 219:188
        lo_rdata,         // 187:156
        inst2_pc,         // 155:124
        inst2,            // 123:92
        inst2_info[27:0], // 91:64
        rdata2_i2,        // 63:32
        rdata1_i2         // 31:0
    } : {124'b0,inst2_pc,124'b0};

    /*wire notes
    is_delayslot,   // 279
    we_i,           // 278
    waddr,          // 277:273
    raddr,          // 272:268
    excepttype      // 267:236
    mem_op,         // 235:228
    hilo_op,        // 227:220
    hi_rdata,       // 219:188
    lo_rdata,       // 187:156
    id_pc,          // 155:124
    inst,           // 123:92
    alu_op,         // 91:80
    sel_alu_src1,   // 79:77
    sel_alu_src2,   // 76:73
    data_ram_en,    // 72
    data_ram_wen,   // 71
    rf_we,          // 70
    rf_waddr,       // 69:65
    sel_rf_res,     // 64
    rdata1,         // 63:32
    rdata2          // 31:0
    */

    assign id_to_ex_bus = switch ? {switch, inst1_bus, inst2_bus, inst1_launch, inst2_launch} :
                                   {switch, inst2_bus, inst1_bus, inst2_launch, inst1_launch} ;

endmodule