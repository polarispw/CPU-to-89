`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,
    output wire stallreq_for_ex,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (flush) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [`ID_INST_INFO-1:0] inst1_bus, inst2_bus;
    wire inst1_valid, inst2_valid;
    wire switch;

    wire stallreq_for_ex_i1, stallreq_for_ex_i2;
    wire [`EX_INST_INFO-1:0] ex_to_mem_bus_i1, ex_to_mem_bus_i2;
    wire [`EX_INFO_BACK-1:0] ex_to_rf_bus_i1, ex_to_rf_bus_i2;
 
    wire data_sram_en_i1, data_sram_en_i2;
    wire [3:0] data_sram_wen_i1, data_sram_wen_i2;
    wire [31:0] data_sram_addr_i1, data_sram_addr_i2;
    wire [31:0] data_sram_wdata_i1, data_sram_wdata_i2;

    assign {inst2_valid, inst1_valid} = id_to_ex_bus_r[1:0];
    assign inst1_bus = id_to_ex_bus_r[281:2]  ;
    assign inst2_bus = id_to_ex_bus_r[561:282];
    assign switch = id_to_ex_bus_r[562];

    sub_ex u1_sub_ex(
        .rst            (rst               ),
        .clk            (clk               ),
        .flush          (flush             ),
        .inst_bus       (inst1_bus         ),
        .stallreq_for_ex(stallreq_for_ex   ),
        .ex_to_mem_bus  (ex_to_mem_bus_i1  ),
        .ex_to_rf_bus   (ex_to_rf_bus_i1   ),
        .data_sram_en   (data_sram_en_i1   ),
        .data_sram_wen  (data_sram_wen_i1  ),
        .data_sram_addr (data_sram_addr_i1 ),
        .data_sram_wdata(data_sram_wdata_i1)
    );// inst1

    sub_ex u2_sub_ex(
        .rst            (rst               ),
        .clk            (clk               ),
        .flush          (flush             ),
        .inst_bus       (inst2_bus         ),
        .stallreq_for_ex(stallreq_for_ex_i2),
        .ex_to_mem_bus  (ex_to_mem_bus_i2  ),
        .ex_to_rf_bus   (ex_to_rf_bus_i2   ),
        .data_sram_en   (data_sram_en_i2   ),
        .data_sram_wen  (data_sram_wen_i2  ),
        .data_sram_addr (data_sram_addr_i2 ),
        .data_sram_wdata(data_sram_wdata_i2)
    );// inst2

    assign data_sram_en    = data_sram_en_i1;
    assign data_sram_wen   = data_sram_wen_i1;
    assign data_sram_addr  = data_sram_addr_i1;
    assign data_sram_wdata = data_sram_wdata_i1;
    
// output

    assign ex_to_mem_bus = switch ? {switch, inst1_valid, inst2_valid, ex_to_mem_bus_i1, ex_to_mem_bus_i2} :
                                    {switch, inst2_valid, inst1_valid, ex_to_mem_bus_i2, ex_to_mem_bus_i1} ;

    assign ex_to_rf_bus = {
        ex_to_rf_bus_i2,
        ex_to_rf_bus_i1
    };
    
endmodule