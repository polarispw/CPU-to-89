`include "lib/defines.vh"
module mycpu_core(
    input wire clk,
    input wire rst,
    input wire [5:0] int,

    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire [31:0] inst_sram_rdata,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus;
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;
    wire [`BR_WD-1:0] br_bus; 
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus;
    wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus;
    wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus;
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;
    wire [`StallBus-1:0] stall;
    wire stallreq_for_load;
    wire stallreq_for_cp0;
    wire stallreq_for_bru;
    wire stallreq_for_ex;
    wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus;
    wire [31:0] new_pc;
    wire flush;

    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .flush           (flush           ),
        .new_pc          (new_pc          ),   
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );
    

    ID u_ID(
    	.clk                (clk               ),
        .rst                (rst               ),
        .flush              (flush             ),
        .stall              (stall             ),
        .stallreq_for_load  (stallreq_for_load ),
        .stallreq_for_cp0   (stallreq_for_cp0  ),
        .stallreq_for_bru   (stallreq_for_bru  ),
        .if_to_id_bus       (if_to_id_bus      ),
        .inst_sram_rdata    (inst_sram_rdata   ),
        .ex_to_rf_bus       (ex_to_rf_bus      ),
        .mem_to_rf_bus      (mem_to_rf_bus     ),
        .wb_to_rf_bus       (wb_to_rf_bus      ),
        .id_to_ex_bus       (id_to_ex_bus      ),
        .br_bus             (br_bus            )
    );

    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .flush           (flush           ),
        .stall           (stall           ),
        .stallreq_for_ex (stallreq_for_ex ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .ex_to_rf_bus    (ex_to_rf_bus    ),
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata )
    );

    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .flush           (flush           ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_rdata (data_sram_rdata ),
        .mem_to_wb_bus   (mem_to_wb_bus   ),
        .mem_to_rf_bus   (mem_to_rf_bus   ),
        .CP0_to_ctrl_bus (CP0_to_ctrl_bus )
    );
    
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .flush             (flush             ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    CTRL u_CTRL(
    	.rst               (rst               ),
        .stallreq_for_ex   (stallreq_for_ex   ),
        .stallreq_for_bru  (stallreq_for_bru  ),
        .stallreq_for_load (stallreq_for_load ),
        .stallreq_for_cp0  (stallreq_for_cp0  ),
        .CP0_to_ctrl_bus   (CP0_to_ctrl_bus   ), 
        .new_pc            (new_pc            ),
        .flush             (flush             ),  
        .stall             (stall             )
    );
    
    
endmodule