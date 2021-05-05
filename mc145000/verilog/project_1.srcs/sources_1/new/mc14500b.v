`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Nobody
// Engineer: Saji Champlin
// 
// Create Date: 02/06/2020 11:53:40 AM
// Design Name: MC14500B ICU
// Module Name: mc14500b
// Project Name: MC145k Computing system
// Target Devices: 
// Tool Versions: 
// Description: 
// A dumb 1 bit computer with associated modules to allow for simple programs.
// Dependencies: 
// None
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mc14500b(
    input clk,
    input rst,
    input [3:0] i_inst,
    input i_data,
    output reg write = 0,
    output reg jmp = 0 ,
    output reg rtn = 0,
    output reg flag0 = 0,
    output reg flagf = 0,
    output reg o_rr = 0,
    output reg o_data = 0
    );
    reg ien = 0, oen = 0;
    reg skip = 0;
    always @(negedge clk or posedge rst) begin
        // Reset any flags from last clock.
        jmp <= 0;
        rtn <= 0;
        flag0 <= 0;
        flagf <= 0;
        write <= 0; // FIX this it's not right technically.
        if (rst) begin
            // reset behavior. reset internal flags and ignore clock.
            ien <= 0;
            oen <= 0;
            o_rr <= 0;
            skip <= 0;
        end else begin
        if (~skip) begin // skip
        case(i_inst)
        4'b0000 : flag0 <= 1; // NOPO
        4'b0001 : o_rr <= ien & i_data; // LD
        4'b0010 : o_rr <= ien & ~i_data; // LDC
        4'b0011 : o_rr <= ien & (i_data & o_rr); // AND
        4'b0100 : o_rr <= ien & (~i_data & o_rr); // NAND
        4'b0101 : o_rr <= ien & (i_data | o_rr); // OR
        4'b0110 : o_rr <= ien & (~i_data | o_rr); // NOR
        4'b0111 : o_rr <= ien & (o_rr == i_data); // XNOR
        4'b1000 : begin // STO
        // DATA -> RR, WRITE -> 1 for a clock (if oen is allowed).
            o_data <= oen & o_rr;
            write <= oen;
        end
        4'b1001 : begin // STOC
        // DATA -> ~RR, WRITE -> 1 for a clock.
            o_data <= ~o_rr;
            write <= oen;
        end
        4'b1010 : ien <= i_data; 
        4'b1011 : oen <= i_data;
        4'b1100 : jmp <= 1;
        4'b1101 : begin // RTN
            rtn <= 1;
            skip <= 1;
        end
        4'b1110 : skip <= ~o_rr;
        4'b1111 : flagf <= 1;
        
        endcase
        end
        else begin // reset skip flag after clocking with skip once.
            skip <= 0;
        end
        end
    end // neg edge
//    always @(posedge clk) begin
//        write <= 0;
//    end
endmodule
