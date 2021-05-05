`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2020 12:29:43 PM
// Design Name: 
// Module Name: main
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module main(
    input [8:0] sw,
    input clock,
    output [7:0] led
    );
    wire [3:0] inst;
    wire i_data;
    wire write;
    wire jmp;
    wire rtn;
    wire flag0;
    wire flagf;
    wire o_rr;
    wire o_data;
    mc14500b cpu(clock, sw[8], inst, i_data, write, jmp, rtn, flag0, flagf, o_rr, o_data);
    mc145ksys sys(clock, o_data, i_data, write, led, inst, sw[7:0]);
endmodule
