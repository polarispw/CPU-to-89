`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus,
    output wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus
);

    reg [`EX_TO_MEM_WD*2+2:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst | flush) begin
            ex_to_mem_bus_r <= {`EX_TO_MEM_WD*2'b0,1'b0};
        end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            ex_to_mem_bus_r <= {`EX_TO_MEM_WD*2'b0,1'b0};
        end
        else if (stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc_i1, mem_pc_i2;
    wire data_ram_en_i1, data_ram_en_i2;
    wire data_ram_wen_i1, data_ram_wen_i2;
    wire [3:0] data_ram_sel_i1, data_ram_sel_i2;
    wire sel_rf_res_i1, sel_rf_res_i2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;
    wire [31:0] rf_wdata_i1, rf_wdata_i2;
    wire [31:0] ex_result_i1, ex_result_i2;
    wire [31:0] mem_result_i1, mem_result_i2;
    wire [`HILO_WD-1:0] hilo_bus_i1, hilo_bus_i2;
    wire [7:0] mem_op_i1, mem_op_i2;
    wire [`EXCEPT_WD -1:0] exceptinfo_i_i1, exceptinfo_i_i2;
    wire inst1_valid, inst2_valid;

    assign {
        inst2_valid,       // 391
        inst1_valid,       // 390
        exceptinfo_i_i2,   // 389:346
        mem_op_i2,         // 345:338
        hilo_bus_i2,       // 337:272
        mem_pc_i2,         // 271:240
        data_ram_en_i2,    // 239
        data_ram_wen_i2,   // 238
        data_ram_sel_i2,   // 237:234
        sel_rf_res_i2,     // 233
        rf_we_i2,          // 232
        rf_waddr_i2,       // 231:227
        ex_result_i2,      // 226:195
        exceptinfo_i_i1,   // 194:151
        mem_op_i1,         // 150:143
        hilo_bus_i1,       // 142:77
        mem_pc_i1,         // 76:45
        data_ram_en_i1,    // 44
        data_ram_wen_i1,   // 43
        data_ram_sel_i1,   // 42:39
        sel_rf_res_i1,     // 38
        rf_we_i1,          // 37
        rf_waddr_i1,       // 36:32
        ex_result_i1       // 31:0
    } =  ex_to_mem_bus_r[391:0];


// load data
    wire inst_lb_i1, inst_lbu_i1, inst_lh_i1, inst_lhu_i1, inst_lw_i1;
    wire inst_lb_i2, inst_lbu_i2, inst_lh_i2, inst_lhu_i2, inst_lw_i2;
    wire inst_sb_i1, inst_sh_i1, inst_sw_i1;
    wire inst_sb_i2, inst_sh_i2, inst_sw_i2;

    assign {
        inst_lb_i1, inst_lbu_i1, inst_lh_i1, inst_lhu_i1, 
        inst_lw_i1, inst_sb_i1,  inst_sh_i1, inst_sw_i1
    } = mem_op_i1;
    assign {
        inst_lb_i2, inst_lbu_i2, inst_lh_i2, inst_lhu_i2, 
        inst_lw_i2, inst_sb_i2,  inst_sh_i2, inst_sw_i2
    } = mem_op_i2;


    wire [7:0] b_data_i1, b_data_i2;
    wire [15:0] h_data_i1, h_data_i2;
    wire [31:0] w_data_i1, w_data_i2;

    assign b_data_i1 = data_ram_sel_i1[3] ? data_sram_rdata[31:24] : 
                       data_ram_sel_i1[2] ? data_sram_rdata[23:16] :
                       data_ram_sel_i1[1] ? data_sram_rdata[15: 8] : 
                       data_ram_sel_i1[0] ? data_sram_rdata[ 7: 0] : 8'b0;
    assign h_data_i1 = data_ram_sel_i1[2] ? data_sram_rdata[31:16] :
                       data_ram_sel_i1[0] ? data_sram_rdata[15: 0] : 16'b0;
    assign w_data_i1 = data_sram_rdata;

    assign mem_result_i1 = inst_lb_i1  ? {{24{b_data_i1[7]}},b_data_i1} :
                           inst_lbu_i1 ? {{24{1'b0}},b_data_i1} :
                           inst_lh_i1  ? {{16{h_data_i1[15]}},h_data_i1} :
                           inst_lhu_i1 ? {{16{1'b0}},h_data_i1} :
                           inst_lw_i1  ? w_data_i1 : 32'b0; 

    assign b_data_i2 = data_ram_sel_i2[3] ? data_sram_rdata[31:24] : 
                       data_ram_sel_i2[2] ? data_sram_rdata[23:16] :
                       data_ram_sel_i2[1] ? data_sram_rdata[15: 8] : 
                       data_ram_sel_i2[0] ? data_sram_rdata[ 7: 0] : 8'b0;
    assign h_data_i2 = data_ram_sel_i2[2] ? data_sram_rdata[31:16] :
                       data_ram_sel_i2[0] ? data_sram_rdata[15: 0] : 16'b0;
    assign w_data_i2 = data_sram_rdata;

    assign mem_result_i2 = inst_lb_i2  ? {{24{b_data_i2[7]}},b_data_i2} :
                           inst_lbu_i2 ? {{24{1'b0}},b_data_i2} :
                           inst_lh_i2  ? {{16{h_data_i2[15]}},h_data_i2} :
                           inst_lhu_i2 ? {{16{1'b0}},h_data_i2} :
                           inst_lw_i2  ? w_data_i2 : 32'b0; 


// CP0
    wire [31:0] cp0_rdata;
    wire [31:0] new_pc;
    wire to_be_flushed;
    wire caused_by_i1, caused_by_i2;

    CP0 u_CP0(
        .rst            (rst             ),
        .clk            (clk             ),
        .exceptinfo_i1  (exceptinfo_i_i1 ),
        .exceptinfo_i2  (exceptinfo_i_i2 ),
        .current_pc_i1  (mem_pc_i1       ),
        .current_pc_i2  (mem_pc_i2       ),
        .rt_rdata_i1    (ex_result_i1    ),
        .rt_rdata_i2    (ex_result_i2    ),
        
        .o_rdata        (cp0_rdata       ),
        .new_pc         (new_pc          ),
        .to_be_flushed  (to_be_flushed   ),
        .caused_by_i1   (caused_by_i1    ),
        .caused_by_i2   (caused_by_i2    )
    );
    
    assign CP0_to_ctrl_bus = {to_be_flushed, new_pc};


// output
    wire [`MEM_INST_INFO-1:0] mem_to_wb_bus_i1, mem_to_wb_bus_i2;

    assign rf_wdata_i1 = sel_rf_res_i1 & data_ram_en_i1 ? mem_result_i1 : 
                         exceptinfo_i_i1[36:32] != 5'b0 ? cp0_rdata     : ex_result_i1;
    assign rf_wdata_i2 = sel_rf_res_i2 & data_ram_en_i2 ? mem_result_i2 : ex_result_i2;

    assign mem_to_wb_bus_i1 = (inst1_valid & ~caused_by_i1) ? //解决有写回要求的跳转指令延迟槽造成例外时flush导致跳转指令写回失败
    {
        hilo_bus_i1,   // 135:70
        mem_pc_i1,     // 69:38
        rf_we_i1,      // 37
        rf_waddr_i1,   // 36:32
        rf_wdata_i1    // 31:0
    } : `MEM_INST_INFO'b0;

    assign mem_to_wb_bus_i2 = (inst2_valid & ~(caused_by_i1 | caused_by_i2)) ?
    {
        hilo_bus_i2,
        mem_pc_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2
    } : `MEM_INST_INFO'b0;

    assign mem_to_wb_bus = {mem_to_wb_bus_i2, mem_to_wb_bus_i1} ;

    assign mem_to_rf_bus = {
        hilo_bus_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2,
        hilo_bus_i1,
        rf_we_i1,
        rf_waddr_i1,
        rf_wdata_i1
    };

endmodule