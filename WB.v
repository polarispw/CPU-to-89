`include "lib/defines.vh"
module WB(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`MEM_TO_WB_WD*2-1:0] mem_to_wb_bus,

    output wire [`WB_TO_RF_WD*2-1:0] wb_to_rf_bus,

    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata 
);

    reg [`MEM_TO_WB_WD*2-1:0] mem_to_wb_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        // else if (flush) begin
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        else if (stall[4]==`NoStop) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;
        end
    end

    wire [31:0] wb_pc_i1, wb_pc_i2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;
    wire [31:0] rf_wdata_i1, rf_wdata_i2;
    wire [`HILO_WD-1:0] hilo_bus_i1, hilo_bus_i2;

    assign {
        hilo_bus_i2,
        wb_pc_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2,
        hilo_bus_i1,
        wb_pc_i1,
        rf_we_i1,
        rf_waddr_i1,
        rf_wdata_i1
    } = mem_to_wb_bus_r;

    assign wb_to_rf_bus = {
        hilo_bus_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2,
        hilo_bus_i1,
        rf_we_i1,
        rf_waddr_i1,
        rf_wdata_i1
    };

    assign debug_wb_pc = wb_pc_i1;
    assign debug_wb_rf_wen = {4{rf_we_i1}};
    assign debug_wb_rf_wnum = rf_waddr_i1;
    assign debug_wb_rf_wdata = rf_wdata_i1;

    
endmodule