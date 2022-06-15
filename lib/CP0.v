`include "defines.vh"
module CP0(
    input wire rst,
    input wire clk,
    input wire [`EXCEPTTYPE_WD-1:0] excepttype_i1,
    input wire [`EXCEPTTYPE_WD-1:0] excepttype_i2,
    input wire [31:0] current_pc_i1,
    input wire [31:0] current_pc_i2,
    input wire [31:0] rt_rdata_i1,
    input wire [31:0] rt_rdata_i2,
    input wire [31:0] bad_addr_i1,
    input wire [31:0] bad_addr_i2,

    output wire [31:0] o_rdata,
    output wire [31:0] new_pc,
    output wire to_be_flushed
);

    reg [31:0] badvaddr;
    reg [31:0] count;//$9
    reg [31:0] status;
    reg [31:0] cause;
    reg [31:0] EPC;
    reg [31:0] compare;//$11
    reg [31:0] r_10010;//$18

    wire [`EXCEPTTYPE_WD-1:0] excepttype;
    wire [31:0] current_pc;
    wire [31:0] rt_rdata;
    wire [31:0] bad_addr;
    wire caused_by_i1, caused_by_i2;
    wire is_in_delayslot;
    wire except_of_pc_addr;
    wire adel;
    wire ades;
    wire except_of_overflow;
    wire except_of_syscall;
    wire except_of_break;
    wire except_of_invalid_inst;
    wire inst_eret;
    wire inst_mfc0;
    wire inst_mtc0;
    wire [4:0] target_addr;
    wire [7:0] interrupt;
    reg [31:0] cp0_rdata;
    reg interrupt_happen;

    assign excepttype = excepttype_i1 | excepttype_i2;
    assign caused_by_i1 = excepttype==excepttype_i1 ? 1'b1 : 1'b0;
    assign caused_by_i2 = excepttype==excepttype_i2 ? 1'b1 : 1'b0;

    assign current_pc = caused_by_i1 ? current_pc_i1 :
                        caused_by_i2 ? current_pc_i2 : 32'b0;
    assign rt_rdata = caused_by_i1 ? rt_rdata_i1 :
                      caused_by_i2 ? rt_rdata_i2 : 32'b0;
    assign bad_addr = caused_by_i1 ? bad_addr_i1 :
                      caused_by_i2 ? bad_addr_i2 : 32'b0;

    assign {
        target_addr,            //15:11
        is_in_delayslot,        //10
        except_of_pc_addr,      //9
        ades,                   //8
        adel,                   //7
        except_of_overflow,     //6
        except_of_syscall,      //5
        except_of_break,        //4
        except_of_invalid_inst, //3
        inst_eret,              //2
        inst_mfc0,              //1
        inst_mtc0               //0
    } = excepttype;

    assign interrupt = cause[15:8]&status[15:8];

    wire except_happen = except_of_overflow | except_of_syscall | except_of_break |
                         except_of_pc_addr  | adel | ades | except_of_invalid_inst|
                         interrupt_happen;

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
            badvaddr <= 32'b0;
            count <= 32'b0;
            status <= {9'b0,1'b1,22'b0};
            cause <= 32'b0;
            EPC <= 32'b0;
            compare <= 32'b0;
            r_10010 <= 32'b0;
        end

        else begin
            if (tick) begin
                count <= count + 1'b1;
            end
            if (compare != 32'b0 && count == compare) begin
                cause[15] <= 1'b1;
            end

            interrupt_happen <= ((interrupt != 8'b0) && status[0] && status[1] == 1'b0) ? 1'b1 : 1'b0;

            if (inst_mtc0) begin
                case (target_addr)
                    5'b01_000:begin
                        badvaddr <= rt_rdata;
                    end 
                    5'b01_001:begin
                        count <= rt_rdata;
                    end
                    5'b01_100:begin
                        status <= {rt_rdata[31:23], 1'b1, rt_rdata[21:0]};
                    end
                    5'b01_101:begin
                        cause <= rt_rdata;
                    end
                    5'b01_110:begin
                        EPC <= rt_rdata;
                    end
                    5'b01_011:begin
                        compare <= rt_rdata;
                        cause[30] <=1'b0;
                    end
                    5'b10_010:begin
                        r_10010 <= rt_rdata;
                    end
                    default:begin
                        
                    end
                endcase
            end

        end
    end
    
    always @ (*) begin
        if (rst) begin
            cp0_rdata <= `ZeroWord;
        end
        
        else if (inst_mfc0) begin
                case (target_addr)
                    5'b01_000:begin
                        cp0_rdata = badvaddr;
                    end 
                    5'b01_001:begin
                        cp0_rdata = count;
                    end
                    5'b01_100:begin
                        cp0_rdata = status;
                    end
                    5'b01_101:begin
                        cp0_rdata = cause;
                    end
                    5'b01_110:begin
                        cp0_rdata = EPC;
                    end
                    default:begin
                        
                    end
                endcase
             end

        if(except_happen) begin
            if (status[1] == 1'b0) begin
                EPC <= is_in_delayslot ? current_pc-32'h4 : current_pc;
                cause[31] <= is_in_delayslot ? 1'b1 : 1'b0;
                status[1] <= 1'b1;
            end
            case ({interrupt_happen,excepttype[9:3]})//interrupt,pc_addr,ades,adel,overflow,syscall,break,invalid_inst
                8'b1000_0000:begin
                    cause[`ExcCode] <= 5'h0;
                    badvaddr <= current_pc; 
                end
                8'b0100_0000:begin
                    cause[`ExcCode] <= 5'h4;
                    badvaddr <= current_pc; 
                end
                8'b0010_0000:begin
                    cause[`ExcCode] <= 5'h5;
                    badvaddr <= bad_addr; 
                end
                8'b0001_0000:begin
                    cause[`ExcCode] <= 5'h4;
                    badvaddr <= bad_addr; 
                end
                8'b0000_1000:begin
                    cause[`ExcCode] <= 5'hc;
                end
                8'b0000_0100:begin
                    cause[`ExcCode] <= 5'h8;
                end
                8'b0000_0010:begin
                    cause[`ExcCode] <= 5'h9;
                end
                8'b0000_0001:begin
                    cause[`ExcCode] <= 5'ha;
                end
                default:begin
                    
                end
            endcase
        end
        else if (inst_eret) begin
            status[1] <= 1'b0;
        end
    end

    assign o_rdata = cp0_rdata;
    assign new_pc = (status[1] == 1'b1) ? 32'hbfc00380 : EPC[31:0];
    assign to_be_flushed = except_happen | inst_eret;

endmodule