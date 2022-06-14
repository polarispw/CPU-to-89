`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD*2:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,

    output wire [`MEM_TO_WB_WD*2-1:0] mem_to_wb_bus,
    output wire [`MEM_TO_RF_WD*2-1:0] mem_to_rf_bus,
    output wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus
);

    reg [`EX_TO_MEM_WD*2:0] ex_to_mem_bus_r;

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
    wire [`EXCEPTTYPE_WD-1:0] excepttype_i_i1, excepttype_i_i2;

    assign {
        excepttype_i_i2,   // 333:318
        mem_op_i2,         // 317:310
        hilo_bus_i2,       // 309:244
        mem_pc_i2,         // 243:212
        data_ram_en_i2,    // 211
        data_ram_wen_i2,   // 210
        data_ram_sel_i2,   // 209:206
        sel_rf_res_i2,     // 205
        rf_we_i2,          // 204
        rf_waddr_i2,       // 203:199
        ex_result_i2,      // 198:167
        excepttype_i_i1,   // 166:151
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
    } =  ex_to_mem_bus_r[333:0];


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
    CP0 u_CP0(
        .rst            (rst             ),
        .clk            (clk             ),
        .excepttype     (excepttype_i_i1 ),
        .bad_addr       (ex_result_i1    ),
        .rt_rdata       (ex_result_i1    ),
        .current_pc     (mem_pc_i1       ),
        .o_rdata        (cp0_rdata       ),
        .new_pc         (new_pc          ),
        .to_be_flushed  (to_be_flushed   )
    );
    assign CP0_to_ctrl_bus = {to_be_flushed, new_pc};


// output
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_i1, mem_to_wb_bus_i2;
    wire switch;

    assign rf_wdata_i1 = sel_rf_res_i1 & data_ram_en_i1 ? mem_result_i1 : 
                         excepttype_i_i1[1]             ? cp0_rdata     : ex_result_i1;
    assign rf_wdata_i2 = sel_rf_res_i2 & data_ram_en_i2 ? mem_result_i2 : ex_result_i2;

    assign mem_to_wb_bus_i1 = {
        hilo_bus_i1,   // 135:70
        mem_pc_i1,     // 69:38
        rf_we_i1,      // 37
        rf_waddr_i1,   // 36:32
        rf_wdata_i1    // 31:0
    };
    assign mem_to_wb_bus_i2 = {
        hilo_bus_i2,
        mem_pc_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2
    };

    assign switch = ex_to_mem_bus_r[334];
    assign mem_to_wb_bus = to_be_flushed ? {`MEM_TO_WB_WD'b0, `MEM_TO_WB_WD'b0} :
                                           {mem_to_wb_bus_i2, mem_to_wb_bus_i1} ;

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