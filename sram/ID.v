`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,
   
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

// IF to FIFO

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
  
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (flush) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;//考虑stall
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end


// FIFO inst buffer

    wire [31:0] inst1_in, inst2_in;
    wire [31:0] inst1_in_pc, inst2_in_pc;
    wire inst1_in_val, inst2_in_val;

    wire [31:0] inst1, inst2;
    wire [31:0] inst1_pc, inst2_pc;
    wire [31:0] inst1_pc_o, inst2_pc_o;
    wire inst1_valid, inst2_valid;
    wire fifo_full;

    wire launched; 
    wire launch_mode;
    wire inst1_is_br,inst2_is_br;
    wire stop_pop;
    reg launch_r;
      
    wire ce, discard_current_inst;
    wire [31:0] id_pc, pc_idef;
    wire matched, inst1_matched, inst2_matched;
    reg [31:0] pc_to_match;
    reg match_pc_en;

    assign {discard_current_inst, ce, pc_idef, id_pc} = if_to_id_bus_r;
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

    assign inst1_in = inst_sram_rdata[31: 0];
    assign inst2_in = inst_sram_rdata[63:32];

    assign inst1_in_pc = id_pc;
    assign inst2_in_pc = inst1_in_val ? id_pc+32'd4 : pc_idef;

    assign inst1_matched = ~match_pc_en | (match_pc_en && inst1_in_pc==pc_to_match);
    assign inst2_matched = ~match_pc_en | (match_pc_en && inst2_in_pc==pc_to_match);
    assign matched = inst1_matched | inst2_matched;

    assign inst1_in_val = ~ce                  ? 1'b0 :
                          id_pc != pc_idef     ? 1'b0 :
                          discard_current_inst ? 1'b0 : 
                          ~inst1_matched       ? 1'b0 : 1'b1;
    assign inst2_in_val = ~ce                  ? 1'b0 :
                          id_pc == 32'b0       ? 1'b0 :
                          discard_current_inst ? 1'b0 : 
                          ~matched             ? 1'b0 : 1'b1;

    assign stallreq_for_fifo = fifo_full & ~br_bus[32];// 队满时要发射的如果恰好是跳转则不能stall 要让IF取址(队列已留出冗余不会真的溢出)
    
    Instbuffer FIFO_buffer(
        .clk                  (clk               ),
        .rst                  (rst               ),
        .flush                (flush | br_bus[32]),
        .stall                ({stall[5:3],stop_pop,stall[1:0]}), 
        .issue_i              (launch_r          ),
        .issue_mode_i         (launch_mode       ),
        .ICache_inst1_i       (inst1_in          ),
        .ICache_inst2_i       (inst2_in          ),
        .ICache_inst1_addr_i  (inst1_in_pc       ),
        .ICache_inst2_addr_i  (inst2_in_pc       ),
        .ICache_inst1_valid_i (inst1_in_val      ),
        .ICache_inst2_valid_i (inst2_in_val      ),

        .issue_inst1_o        (inst1             ),
        .issue_inst2_o        (inst2             ),
        .issue_inst1_addr_o   (inst1_pc_o        ),
        .issue_inst2_addr_o   (inst2_pc_o        ),
        .issue_inst1_valid_o  (inst1_valid       ),
        .issue_inst2_valid_o  (inst2_valid       ),         
        .buffer_full_o        (fifo_full         )
    );

    reg [31:0] inst1_pc_r, inst2_pc_r;
    reg last_inst_is_br, pre_is_br;//后者控制单发射时的延迟槽
    wire [32:0] br_bus1, br_bus2;

    always @(posedge clk) begin
        if(rst | flush | ~br_bus[32]) begin
            last_inst_is_br <= 1'b0;
            inst1_pc_r <= 32'b0;
            inst2_pc_r <= 32'b0;
        end
        else if(br_bus[32]) begin
            last_inst_is_br <= 1'b1;
            inst1_pc_r <= inst1_pc_o;
            inst2_pc_r <= inst2_pc_o;
        end

        if(rst | flush | br_bus1[31:0]==32'b0) begin
            pre_is_br <= 1'b0;
        end
        else if(br_bus1[31:0]!=32'b0 & launch_mode==`SingleIssue) begin
            pre_is_br <= 1'b1;
        end
    end

    assign inst1_pc = last_inst_is_br ? inst1_pc_r : inst1_pc_o;
    assign inst2_pc = last_inst_is_br ? inst2_pc_r : inst2_pc_o;


// bypass and WB signal declare 

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
    // both hi/lo reg are unique, there is no need to declare twice(i1,i2)

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
    assign launch_mode   = br_bus1[32]                     ? `DualIssue   :
                           (data_corelate | inst_conflict) ? `SingleIssue : 
                           inst2_is_br                     ? `SingleIssue :
                           ~inst2_valid                    ? `SingleIssue : `DualIssue;     
    assign launched      = (inst1_valid | inst2_valid) & ~stallreq_for_cp0; // 这里要再考虑

    always@(*)begin
        if(rst | flush) begin
            launch_r <= 1'b0;
        end
        else begin
            launch_r <= launched;
        end
    end

    assign stop_pop = (stall[2]) | inst1_info[28] | inst1_info[29];// stall或发射除法后不再弹出


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
    } : {124'b0,inst1_pc_r,124'b0};

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
    } : {124'b0,inst2_pc_r,124'b0};

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