//BUS BETWEEN MODULES
`define IF_TO_ID_WD 66
`define ID_TO_EX_WD 507
`define EX_TO_MEM_WD 336
`define MEM_TO_WB_WD 272

`define ID_INST_INFO 252
`define EX_INST_INFO 167
`define MEM_INST_INFO 136

`define BR_WD 33
`define CP0_TO_CTRL_WD 33
`define STALLBUS_WD 6
`define EXCEPTINFO_WD 16

`define EX_INFO_BACK 105
`define MEM_INFO_BACK 104
`define WB_INFO_BACK 104
`define HILO_WD 66

`define EX_TO_RF_WD 210
`define MEM_TO_RF_WD 208
`define WB_TO_RF_WD 208

// MACRO
`define Stop 1'b1
`define NoStop 1'b0
`define ZeroWord 32'b0
`define TTbits_wire 31:0
`define SFbits_wire 63:0
`define ExcCode 6:2

// DIV
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0

// FIFO
`define InstBufferSize     32           
`define InstBufferSizeLog2 5            
`define Valid              1'b1               
`define Invalid            1'b0
`define DualIssue          1'b1      
`define SingleIssue        1'b0               
`define ValidPrediction    1'b1
`define InValidPrediction  1'b0
`define InstBus            31:0
`define InstAddrBus        31:0