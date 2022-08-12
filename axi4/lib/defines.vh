//BUS BETWEEN MODULES
`define IF_TO_ID_WD 65
`define ID_TO_EX_WD 573
`define EX_TO_MEM_WD 401
`define MEM_TO_WB_WD 272

`define INST_INFO 93
`define ID_INST_INFO 285
`define EX_INST_INFO 199
`define MEM_INST_INFO 136

`define BR_WD 33
`define CP0_TO_CTRL_WD 33
`define STALLBUS_WD 6
`define EXCEPTINFO_WD 16
`define EXCEPT_WD 44

`define EX_INFO_BACK 106
`define MEM_INFO_BACK 104
`define WB_INFO_BACK 104
`define HILO_WD 66

`define EX_TO_RF_WD 212
`define MEM_TO_RF_WD 208
`define WB_TO_RF_WD 208

// MACRO
`define Stop 1'b1
`define NoStop 1'b0
`define ZeroWord 32'b0
`define TTbits_wire 31:0
`define SFbits_wire 63:0

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
`define FIFOSize      32           
`define FIFOSizebits  4            
`define Valid         1'b1               
`define Invalid       1'b0
`define DualIssue     1'b1      
`define SingleIssue   1'b0    
`define InstBus       31:0
`define InstAddrBus   31:0
`define FIFOLine      16
`define ZEROTAG       27'b0
`define Lowbits       31:0
`define Highbits      63:32

// CP0
`define ExcCode 6:2
`define PrioCode 11:8
`define CP0_REG_COUNT    5'b01001          //可读写
`define CP0_REG_COMPARE  5'b01011          //可读写
`define CP0_REG_STATUS   5'b01100          //可读写
`define CP0_REG_CAUSE    5'b01101          //只读
`define CP0_REG_EPC      5'b01110          //可读写
`define CP0_REG_CONFIG   5'b10000          //只读
`define CP0_REG_BADADDR  5'b01000
`define CP0_REG_ENTRYLO0 5'b00010
`define CP0_REG_ENTRYLO1 5'b00011
`define CP0_REG_ENTRYHI  5'b01010
`define CP0_REG_INDEX    5'b00000
`define INTERRUPT        32'h00000500
`define Mod              32'h00000201
`define TLBL             32'h00000202
`define TLBS             32'h00000203
`define LOADASSERT       32'h00000104
`define PCASSERT         32'h00000404
`define STOREASSERT      32'h00000105
`define SYSCALL          32'h00000208
`define BREAK            32'h00000509
`define INVALIDINST      32'h0000030a
`define TRAP             32'h0000020d
`define OV               32'h0000020c
`define ERET             32'h0000050e

// cache
`define TAG_WIDTH 21    // tag + v
`define INDEX_WIDTH 64  // 块高  // depth
`define CACHELINE_WIDTH 512
`define HIT_WIDTH 2
`define LRU_WIDTH 1