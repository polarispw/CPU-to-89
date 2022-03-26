`include "defines.vh"
module CP0(
    input wire rst,
    input wire [13:0] excepttype,
    input wire [31:0] current_pc,
    input wire [31:0] rt_rdata,

    output wire [31:0] o_rdata,
    output wire [31:0] new_pc,
    output wire to_be_flushed
);

    reg [31:0] badvaddr;
    reg [31:0] count;
    reg [31:0] status;
    reg [31:0] cause;
    reg [31:0] EPC;
    reg [31:0] compare;
    reg [31:0] r_10010;


    wire is_in_delayslot;
    wire except_of_addr;
    wire except_of_overflow;
    wire except_of_syscall;
    wire except_of_break;
    wire except_of_invalid_inst;
    wire inst_eret;
    wire inst_mfc0;
    wire inst_mtc0;
    wire[4:0] target_addr;
    reg [31:0] cp0_rdata;

    assign {target_addr, is_in_delayslot, except_of_addr, except_of_overflow, except_of_syscall, 
            except_of_break, except_of_invalid_inst, inst_eret, inst_mfc0, inst_mtc0} 
            = excepttype;

    wire except_happen = except_of_overflow | except_of_syscall | except_of_break;

    always @ (*) begin
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
            if (inst_mfc0) begin
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
            else if (inst_mtc0) begin
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
                    end
                    5'b10_010:begin
                        r_10010 <= rt_rdata;
                    end
                    default:begin
                        
                    end
                endcase
            end
            if(except_happen && (status[1]==0)) begin
                EPC <= is_in_delayslot ? current_pc-32'h4 : current_pc;
                cause[31] <= is_in_delayslot ? 1'b1 : 1'b0;
                status[1] <= 1'b1;
                case (excepttype[7:3])
                    5'b100_00:begin
                        cause[`ExcCode] <= 5'h4;
                    end
                    5'b010_00:begin
                        cause[`ExcCode] <= 5'hc;
                    end
                    5'b001_00:begin
                        cause[`ExcCode] <= 5'h8;
                    end
                    5'b000_10:begin
                        cause[`ExcCode] <= 5'h9;
                    end
                    5'b000_01:begin
                        cause[`ExcCode] <= 5'ha;
                    end
                    default:begin
                        
                    end
                endcase
            end
            else if(inst_eret) begin
                status[1] <= 1'b0;
            end
        end
    end
    
    assign o_rdata = cp0_rdata;
    assign new_pc = (status[1] ==1'b1) ? 32'hbfc00380 : EPC[31:0];
    assign to_be_flushed = except_happen | inst_eret;

endmodule
