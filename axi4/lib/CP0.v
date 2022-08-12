`include "defines.vh"
module CP0(
    input wire rst,
    input wire clk,
    input wire [5:0] int,
    input wire [`EXCEPT_WD-1:0] exceptinfo_i1,
    input wire [`EXCEPT_WD-1:0] exceptinfo_i2,
    input wire [31:0] current_pc_i1,
    input wire [31:0] current_pc_i2,
    input wire [31:0] rt_rdata_i1,
    input wire [31:0] rt_rdata_i2,

    output wire [31:0] o_rdata,
    output wire [31:0] new_pc,
    output wire to_be_flushed,
    output wire caused_by_i1, 
    output wire caused_by_i2
);

    reg [31:0] badvaddr;
    reg [31:0] count;//$9
    reg [31:0] status;
    reg [31:0] cause;
    reg [31:0] epc;
    reg [31:0] compare;//$11
    reg [31:0] r_10010;//$18
    reg [31:0] entrylo0;
    reg [31:0] entrylo1;
    reg [31:0] entryhi;
    reg [31:0] index;
    reg [31:0] cp0_rdata;

    wire [31:0] current_pc;
    wire [31:0] rt_rdata;
    wire [31:0] bad_addr;
   
    wire we_i, is_delayslot;
    wire except_happen;
    wire [4:0] waddr, raddr;
    wire [31:0] excepttype_i, excepttype;
    wire [`EXCEPT_WD-1:0] exceptinfo;

    assign except_happen = (exceptinfo_i1[31:0] | exceptinfo_i2[31:0]) != `ZeroWord            ? 1'b1 :
                           (((cause[15:8] & status[15:8]) != 8'b0) && status[0] && ~status[1]) ? 1'b1 : 1'b0;

    assign caused_by_i1 = exceptinfo_i1[31:0]==`ZeroWord ? 1'b0 : 1'b1;
    assign caused_by_i2 = exceptinfo_i2[31:0]==`ZeroWord ? 1'b0 : 1'b1;

    assign exceptinfo = caused_by_i2 ? exceptinfo_i2 : exceptinfo_i1;
    assign current_pc = caused_by_i2 ? current_pc_i2 : current_pc_i1;
    assign rt_rdata   = rt_rdata_i1;
    assign bad_addr   = caused_by_i2 ? rt_rdata_i2 : rt_rdata_i1;

    assign {
        is_delayslot, // 43
        we_i,         // 42
        waddr,        // 41:37
        raddr,        // 36:32
        excepttype_i  // 31:0
    } = exceptinfo;

    assign excepttype = (((cause[15:8] & status[15:8]) != 8'b0) && status[0] && ~status[1]) ? `INTERRUPT : excepttype_i;

    reg tick;
    always @ (posedge clk) begin
        if (rst) begin
            tick <= 1'b0;
        end
        else begin
            tick <= ~tick;
        end
    end

    always @ (posedge clk) begin
        if (rst) begin
            badvaddr <= `ZeroWord;
            count    <= `ZeroWord;
            status   <= {4'b0001,28'd0};
            cause    <= `ZeroWord;
            epc      <= `ZeroWord;
            compare  <= `ZeroWord;
            r_10010  <= `ZeroWord;
            entrylo0 <= `ZeroWord;
            entrylo1 <= `ZeroWord;
            entryhi  <= `ZeroWord;
            index    <= `ZeroWord;
        end

        else begin
            if (tick) begin
                count <= count + 1'b1;
            end
            cause[15:10] <= int;
            if (compare != 32'b0 && count == compare) begin
                cause[15] <= 1'b1;
            end

            if (we_i) begin
                case (waddr)
                    `CP0_REG_COUNT:begin
                        count <= rt_rdata;
                    end
                    `CP0_REG_STATUS:begin
                        status <= rt_rdata;
                    end
                    `CP0_REG_CAUSE:begin
                        cause <= rt_rdata;
                    end
                    `CP0_REG_EPC:begin
                        epc <= rt_rdata;
                    end
                    `CP0_REG_COMPARE:begin
                        compare <= rt_rdata;
                        cause[30] <= 1'b0;
                    end
                    5'b10_010:begin
                        r_10010 <= rt_rdata;
                    end
                    default:begin
                        
                    end
                endcase
            end

            if(except_happen) begin 
                if (~status[1] && (excepttype!=`ERET)) begin
                    status[1] <= 1'b1;
                    cause[31] <= is_delayslot ? 1'b1 : 1'b0;
                    epc       <= is_delayslot ? current_pc-32'h4 : current_pc;
                end
                case (excepttype)
                    `INTERRUPT:begin
                        cause[`ExcCode] <= 5'h0;
                        badvaddr <= current_pc; 
                    end
                    `PCASSERT:begin
                        cause[`ExcCode] <= 5'h4;
                        badvaddr <= current_pc; 
                    end
                    `LOADASSERT:begin
                        cause[`ExcCode] <= 5'h4;
                        badvaddr <= bad_addr; 
                    end
                    `STOREASSERT:begin
                        cause[`ExcCode] <= 5'h5;
                        badvaddr <= bad_addr; 
                    end
                    `SYSCALL:begin
                        cause[`ExcCode] <= 5'h8;
                    end
                    `BREAK:begin
                        cause[`ExcCode] <= 5'h9;
                    end
                    `INVALIDINST:begin
                        cause[`ExcCode] <= 5'ha;
                    end
                    `OV:begin
                        cause[`ExcCode] <= 5'hc;
                    end
                    `ERET:begin
                        status[1] <= 1'b0;
                    end
                    default:begin
                        
                    end
                endcase
            end
        end
    end
    
    always @ (*) begin
        if (rst) begin
            cp0_rdata = `ZeroWord;
        end
        else begin
            case (raddr)
                `CP0_REG_BADADDR:begin
                    cp0_rdata = badvaddr;
                end 
                `CP0_REG_COUNT:begin
                    cp0_rdata = count;
                end
                `CP0_REG_STATUS:begin
                    cp0_rdata = status;
                end
                `CP0_REG_CAUSE:begin
                    cp0_rdata = cause;
                end
                `CP0_REG_EPC:begin
                    cp0_rdata = epc;
                end
                default:begin
                    cp0_rdata = `ZeroWord;
                end
            endcase
        end
    end

    assign o_rdata = cp0_rdata;
    assign new_pc = excepttype==`ERET ? epc[31:0]    :
                    except_happen     ? 32'hbfc00380 : `ZeroWord;
    assign to_be_flushed = except_happen;

endmodule