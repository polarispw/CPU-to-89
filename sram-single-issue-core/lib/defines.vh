`define IF_TO_ID_WD 33
`define ID_TO_EX_WD 280
`define EX_TO_MEM_WD 195
`define MEM_TO_WB_WD 136
`define BR_WD 33
`define DATA_SRAM_WD 69
`define EX_TO_RF_WD 105
`define MEM_TO_RF_WD 104
`define WB_TO_RF_WD 104
`define HILO_WD 66
`define EXCEPTTYPE_WD 15
`define CP0_TO_CTRL_WD 33

`define StallBus 6
`define NoStop 1'b0
`define Stop 1'b1
`define ZeroWord 32'b0


//除法div
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0

//CP0
`define EXCEPT_WD 44
`define ExcCode 6:2
`define PrioCode 11:8
`define CP0_REG_COUNT      5'b01001          //可读写
`define CP0_REG_COMPARE    5'b01011          //可读写
`define CP0_REG_STATUS     5'b01100          //可读写
`define CP0_REG_CAUSE      5'b01101          //只读
`define CP0_REG_EPC        5'b01110          //可读写
`define CP0_REG_CONFIG     5'b10000          //只读
`define CP0_REG_BADADDR    5'b01000
`define INTERRUPT        32'h00000501
`define LOADASSERT       32'h00000104
`define PCASSERT         32'h00000404
`define STOREASSERT      32'h00000105
`define SYSCALL          32'h00000208
`define BREAK            32'h00000509
`define INVALIDINST      32'h0000030a
`define TRAP             32'h0000020d
`define OV               32'h0000020c
`define ERET             32'h0000050e