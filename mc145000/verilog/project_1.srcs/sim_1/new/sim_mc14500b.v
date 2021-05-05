`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/06/2020 09:33:01 PM
// Design Name: 
// Module Name: sim_mc14500b
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


module sim_mc14500b();
    reg [3:0] inst = 4'b0000;
    reg clk = 1, i_data = 0 , rst = 0;
    wire write, jmp, rtn, flag0, flagf, o_rr, o_data;
    mc14500b DUT(clk, rst, inst, i_data, write, jmp, rtn, flag0, flagf, o_rr, o_data);
    reg [2:0] ii = 0;

    always begin
        #5 clk = ~clk;
    end
    initial begin
        // Actually test stuff here. Go through each instruction. and both cases
        inst = 4'b0000;
        @(posedge clk);
        if (flag0) $display("FLAG0 PASS");
        else $display ("FLAG0 FAIL");
        
        inst = 4'b1111;
        @(posedge clk);
        if (flagf) $display("FLAGF PASS");
        else $display ("FLAGF FAIL");
        // Enable IEN
        inst = 4'b1010;
        i_data = 1;
        @(posedge clk);
        // LD
        inst = 4'b0001;
        i_data = 1;
        @(posedge clk);
        if (o_rr) $display("LD 1 PASS");
        else $display("LD 1 FAIL");
        inst = 4'b0001;
        i_data = 0;
        @(posedge clk);
        if (~o_rr) $display("LD 0 PASS");
        else $display("LD 0 FAIL");
        
        
        // LDC
        inst = 4'b0010;
        i_data = 1;
        @(posedge clk);
        if (~o_rr) $display("LDC 1 PASS");
        else $display("LDC 1 FAIL");
        inst = 4'b0010;
        i_data = 0;
        @(posedge clk);
        if (o_rr) $display("LDC 0 PASS");
        else $display("LDC 0 FAIL");        
        
        // IEN 0
        inst = 4'b1010;
        i_data = 0;
        @(posedge clk);
        // LD anything
        inst = 4'b0001;
        i_data = 0;
        @(posedge clk);
        if (~o_rr) $display("IEN RST PASS");
        else $display("IEN RST FAIL");
        
        // Enable IEN
        inst = 4'b1010;
        i_data = 1;
        @(posedge clk);
        for (ii = 0; ii < 4; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            i_data = ii[1]; // second bit to data
            inst = 4'b0011; // AND
            @(posedge clk);
            // Compare output to expected.
            if (o_rr == (ii[0] & ii[1])) $display("%b AND %b PASS", ii[0], ii[1]);
            else $display("%b AND %b FAIL", ii[0], ii[1]);
        end
        // ANDC
        for (ii = 0; ii < 4; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            i_data = ii[1]; // second bit to data
            inst = 4'b0100; // ANDC
            @(posedge clk);
            // Compare output to expected.
            if (o_rr == (ii[0] & ~ii[1])) $display("%b ANDC %b PASS", ii[0], ii[1]);
            else $display("%b ANDC %b FAIL", ii[0], ii[1]);
        end
        // OR
        for (ii = 0; ii < 4; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            i_data = ii[1]; // second bit to data
            inst = 4'b0101; // OR
            @(posedge clk);
            // Compare output to expected.
            if (o_rr == (ii[0] | ii[1])) $display("%b OR %b PASS", ii[0], ii[1]);
            else $display("%b OR %b FAIL", ii[0], ii[1]);
        end
        // ORC
        for (ii = 0; ii < 4; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            i_data = ii[1]; // second bit to data
            inst = 4'b0110; // ORC
            @(posedge clk);
            // Compare output to expected.
            if (o_rr == (ii[0] | ~ii[1])) $display("%b OR %b PASS", ii[0], ii[1]);
            else $display("%b OR %b FAIL", ii[0], ii[1]);
        end
        
        // XNOR
        for (ii = 0; ii < 4; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            i_data = ii[1]; // second bit to data
            inst = 4'b0111; // XNOR
            @(posedge clk);
            // Compare output to expected.
            if (o_rr == (ii[0] == ii[1])) $display("%b XNOR %b PASS", ii[0], ii[1]);
            else $display("%b XNOR %b FAIL EXPECT %B GOT %B", ii[0], ii[1], o_rr, (ii[0] == ii[1]));
        end
        
        // OEN on
        inst = 4'b1011;
        i_data = 1;
        @(posedge clk);
        // STO
        for (ii = 0; ii < 2; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            inst = 4'b1000; // STO RR -> DATA, WRITE <- 1
            @(posedge clk);
            // Compare output to expected.
            if ((ii[0] == o_data) & (write == 1)) $display("STO %b PASS", ii[0]);
            else $display("STO %b FAIL", ii[0]);
        end
        // STOC
        for (ii = 0; ii < 2; ii = ii + 1) begin
        // LD
            inst = 4'b0001;
            i_data = ii[0]; // load first bit to rr
            @(posedge clk);
            inst = 4'b1001; // STOC ~RR -> DATA, WRITE <- 1
            @(posedge clk);
            // Compare output to expected.
            if ((~ii[0] == o_data) & (write == 1)) $display("STOC %b PASS", ii[0]);
            else $display("STOC %b FAIL", ii[0]);
        end
        
        // JMP
        inst = 4'b1100; // JMP
        @(posedge clk);
        if (jmp == 1) $display("JMP PASS");
        else $display("JMP FAIL");
        
        // RTN
        
        inst = 4'b1101; // RTN
        @(posedge clk);
        if (rtn == 1)$display("RTN PASS");
        else $display("RTN FAIL");
        // it should skip the next instruction.
        inst = 4'b0000; // NOPO
        @(posedge clk);
        if (~flag0)$display("RTN SKIP PASS");
        else $display("RTN SKIP FAIL");

        // SKZ
        // LD 1
        inst = 4'b0001;
        i_data = 1;
        @(posedge clk);
        // SKZ should not skip
        inst = 4'b1110;
        @(posedge clk);
        inst = 4'b0000; // NOPO
        @(posedge clk);
        if (flag0)$display("SKZ NOSKIP PASS");
        else $display("SKZ NOSKIP FAIL");
        
        inst = 4'b0001;
        i_data = 0;
        @(posedge clk);
        // SKZ should not skip
        inst = 4'b1110;
        @(posedge clk);
        inst = 4'b0000; // NOPO
        @(posedge clk);
        if (~flag0)$display("SKZ SKIP PASS");
        else $display("SKZ SKIP FAIL");
        
        repeat(10) @(posedge clk);
        $finish;
    end
endmodule
