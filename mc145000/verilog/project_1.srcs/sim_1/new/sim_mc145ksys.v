`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2020 03:06:45 PM
// Design Name: 
// Module Name: sim_mc145ksys
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


module sim_mc145ksys();
    reg clk = 0, write = 0, i_data = 0;
    wire [7:0] out;
    wire o_data;
    wire [3:0] inst;
    reg [7:0] in = 0;
    mc145ksys DUT(clk, i_data, o_data, write, out, inst, in);
    always begin
        #5 clk = ~clk;
    end
    initial begin
        $dumpvars;
        repeat(16) @(posedge clk);
        i_data <= 1;
        write <= 1;
        repeat(16) @(posedge clk);
        i_data <= 0;
        repeat(16) @(posedge clk);
        // inst should be
        $finish;
    end
endmodule
