`include "lib/defines.vh"
module CTRL(
    input wire rst,
    input wire stallreq_for_ex,
    input wire stallreq_for_bru,
    input wire stallreq_for_load,
    input wire stallreq_for_cp0,
    input wire stallreq_cache,
    input wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus,

    output reg flush,
    output reg [31:0] new_pc,
    output reg [`StallBus-1:0] stall
);  
    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;
        end
        else if (stallreq_cache) begin
            stall = `StallBus'b011111;
        end
        else if (stallreq_for_ex) begin
            stall = `StallBus'b001111;
        end
        else if (stallreq_for_bru | stallreq_for_cp0) begin
            stall = `StallBus'b000111;
        end
        else if (stallreq_for_load) begin
            stall = `StallBus'b000011;
        end
        else begin
            stall = `StallBus'b0;
        end
    end

    always @ (*) begin
        if (rst) begin
            flush <= 1'b0;
            new_pc <= 32'b0;
        end
        else if (stallreq_cache) begin
            
        end
        else if (CP0_to_ctrl_bus[32] == 1'b1) begin
            flush <= 1'b1;
            new_pc <= CP0_to_ctrl_bus[31:0];
        end
        else begin
            flush <= 1'b0;
            new_pc <= 32'b0;
        end
    end
endmodule