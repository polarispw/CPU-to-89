`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus,
    output wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (flush) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire data_ram_wen;
    wire [3:0] data_ram_sel;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;
    wire [`HILO_WD-1:0] hilo_bus;
    wire [7:0] mem_op;
    wire [14:0] excepttype_i;

    assign {
        excepttype_i,   // 165:151
        mem_op,         // 150:143
        hilo_bus,       // 142:77
        mem_pc,         // 76:45
        data_ram_en,    // 44
        data_ram_wen,   // 43
        data_ram_sel,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;



    wire inst_lb,   inst_lbu,   inst_lh,    inst_lhu,   inst_lw;
    wire inst_sb,   inst_sh,    inst_sw;

    assign {
        inst_lb, inst_lbu, inst_lh, inst_lhu, 
        inst_lw, inst_sb, inst_sh, inst_sw
    } = mem_op;

    wire [7:0] b_data;
    wire [15:0] h_data;
    wire [31:0] w_data;

    assign b_data = data_ram_sel[3] ? data_sram_rdata[31:24] : 
                    data_ram_sel[2] ? data_sram_rdata[23:16] :
                    data_ram_sel[1] ? data_sram_rdata[15: 8] : 
                    data_ram_sel[0] ? data_sram_rdata[ 7: 0] : 8'b0;
    assign h_data = data_ram_sel[2] ? data_sram_rdata[31:16] :
                    data_ram_sel[0] ? data_sram_rdata[15: 0] : 16'b0;
    assign w_data = data_sram_rdata;

    assign mem_result = inst_lb     ? {{24{b_data[7]}},b_data} :
                        inst_lbu    ? {{24{1'b0}},b_data} :
                        inst_lh     ? {{16{h_data[15]}},h_data} :
                        inst_lhu    ? {{16{1'b0}},h_data} :
                        inst_lw     ? w_data : 32'b0; 

    wire [31:0] cp0_rdata;
    wire [31:0] new_pc;
    wire to_be_flushed;
    CP0 u_CP0(
        .rst            (rst          ),
        .excepttype     (excepttype_i ),
        .bad_addr       (ex_result    ),
        .rt_rdata       (ex_result    ),
        .current_pc     (mem_pc       ),
        .o_rdata        (cp0_rdata    ),
        .new_pc         (new_pc       ),
        .to_be_flushed  (to_be_flushed)
    );
    assign CP0_to_ctrl_bus = {to_be_flushed, new_pc};

    assign rf_wdata = sel_rf_res & data_ram_en ? mem_result : 
                      excepttype_i[1] ? cp0_rdata : ex_result;

    assign mem_to_wb_bus = to_be_flushed ? `MEM_TO_WB_WD'b0 :
    {
        hilo_bus,   // 135:70
        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };

    assign mem_to_rf_bus = {
        hilo_bus,
        rf_we,
        rf_waddr,
        rf_wdata
    };




endmodule