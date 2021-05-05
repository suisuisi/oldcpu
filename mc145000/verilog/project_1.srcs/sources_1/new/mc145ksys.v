`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2020 10:12:15 AM
// Design Name: 
// Module Name: mc145ksys
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

module mc145ksys(
    input clk,
    input i_data,
    output reg o_data,
    input write_en,
    output reg [7:0] o_io = 0,
    output reg [3:0] o_inst,
    input [7:0] i_io
    );
    reg [7:0] ram = 0;
    reg [7:0] rom [511:0];
    reg [8:0] pc = 0;
    initial $readmemh("rom.mem", rom);
    always @(negedge clk) begin
        // update instruction
        o_inst <= rom[pc][7:4];
        if (write_en) begin
            // we have to set the address from the ROM to i_data;
            if (rom[pc][3:0] > 7) // If it's accessing RAM
                ram[rom[pc][3:0] - 'h8] <= i_data;
            else
                o_io[rom[pc][3:0]] <= i_data;

        end else begin
            // we are not writing, so get the address and load it to o_data;
            if (rom[pc][3:0] > 7) // If it's accessing RAM
                 o_data <= ram[rom[pc][3:0] - 'h8];
            else // Accessing inputs.
                o_data <= i_io[rom[pc][3:0]];
        end
        pc <= pc + 1;
    end
endmodule
