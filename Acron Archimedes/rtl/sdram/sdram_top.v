/*	sdram_top.v

	Copyright (c) 2013-2014, Stephen J. Leary
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:
		 * Redistributions of source code must retain the above copyright
			notice, this list of conditions and the following disclaimer.
		 * Redistributions in binary form must reproduce the above copyright
			notice, this list of conditions and the following disclaimer in the
			documentation and/or other materials provided with the distribution.
		 * Neither the name of the Stephen J. Leary nor the
			names of its contributors may be used to endorse or promote products
			derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL STEPHEN J. LEARY BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
*/

module sdram_top (

	// interface to the MT48LC16M16 chip
	input             sd_clk,         // sdram is accessed at 128MHz
	input             sd_rst,         // reset the sdram controller.
	output            sd_cke,         // clock enable.
	inout  reg [15:0] sd_dq,          // 16 bit bidirectional data bus
	output reg [12:0] sd_addr,        // 13 bit multiplexed address bus
	output reg  [1:0] sd_dqm = 2'b00, // two byte masks
	output reg  [1:0] sd_ba = 2'b00,  // two banks
	output            sd_cs_n,        // a single chip select
	output            sd_we_n,        // write enable
	output            sd_ras_n,       // row address select
	output            sd_cas_n,       // columns address select
	output reg        sd_ready = 0,   // sd ready.

	// cpu/chipset interface

	input             wb_clk,         // 32MHz chipset clock to which sdram state machine is synchonized
	input      [31:0] wb_dat_i,       // data input from chipset/cpu
	output reg [31:0] wb_dat_o = 0,   // data output to chipset/cpu
	output reg        wb_ack = 0,
	input      [23:0] wb_adr,         // lower 2 bits are ignored.
	input       [3:0] wb_sel,         //
	input       [2:0] wb_cti,         // cycle type.
	input             wb_stb,         //
	input             wb_cyc,         // cpu/chipset requests cycle
	input             wb_we           // cpu/chipset requests write
);

`include "sdram_defines.v"

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

reg   [3:0] t;
reg   [4:0] reset;

reg  [31:0] sd_dat[4]; // data output to chipset/cpu
reg   [2:0] sd_word;

reg         sd_we = 1'b0; // copy of the wishbone bus signal.

reg   [4:0] sd_cycle= 5'd0;
reg         sd_done = 1'b0;

reg   [3:0] sd_cmd = 4'd0;   // current command sent to sd ram

reg   [9:0] sd_refresh = 10'd0;
reg         sd_auto_refresh = 1'b0;
reg         sd_need_refresh = 1'b0;
wire        sd_req = wb_stb & wb_cyc & ~wb_ack;
reg         sd_req_reg;
reg         sd_cache_hit;
reg  [11:0] sd_active_row[3:0];
reg   [3:0] sd_bank_active;
wire  [1:0] sd_bank = wb_adr[22:21];
wire [11:0] sd_row = wb_adr[20:9];
reg  [23:0] sd_last_adr;
reg  [15:0] sd_latch;

initial begin
	t       = 4'd0;
	reset   = 5'h1f;
	sd_addr = 13'd0;
	sd_cmd  = CMD_INHIBIT;
end

localparam CYCLE_PRECHARGE  = 5'd0;
localparam CYCLE_RAS_START  = 5'd3;
localparam CYCLE_RAS_CONT   = CYCLE_RAS_START + 1'd1;
localparam CYCLE_RFSH_START = CYCLE_RAS_START; 
localparam CYCLE_CAS0       = CYCLE_RAS_START  + RASCAS_DELAY;
localparam CYCLE_CAS1       = CYCLE_CAS0 + 1'd1;
localparam CYCLE_CAS2       = CYCLE_CAS1 + 1'd1;
localparam CYCLE_READ0      = CYCLE_CAS0 + CAS_LATENCY + 2'd2;
localparam CYCLE_READ1      = CYCLE_READ0+ 1'd1;
localparam CYCLE_READ2      = CYCLE_READ1+ 1'd1;
localparam CYCLE_READ3      = CYCLE_READ2+ 1'd1;
localparam CYCLE_READ4      = CYCLE_READ3+ 1'd1;
localparam CYCLE_READ5      = CYCLE_READ4+ 1'd1;
localparam CYCLE_READ6      = CYCLE_READ5+ 1'd1;
localparam CYCLE_READ7      = CYCLE_READ6+ 1'd1;
localparam CYCLE_END        = CYCLE_READ7;
localparam CYCLE_RFSH_END   = CYCLE_RFSH_START + RFC_DELAY;

// 64ms/8192 rows = 7.8us
localparam RAM_CLK = 120;
localparam REFRESH_PERIOD = (16'd78 * RAM_CLK / 4'd10) - CYCLE_END;

`ifdef VERILATOR
reg [15:0] sd_q;
assign sd_dq = (sd_we && (sd_cycle == CYCLE_CAS1 || sd_cycle == CYCLE_CAS2)) ? sd_q : 16'bZZZZZZZZZZZZZZZZ;
`endif

always @(posedge sd_clk, posedge sd_rst) begin

	if (sd_rst) begin
		t        <= 4'd0;
		reset    <= 5'h1f;
		sd_addr  <= 13'd0;
		sd_ready <= 0;
		sd_last_adr <= 24'hffffff;
		sd_need_refresh <= 1'b0;
	end else begin
`ifndef VERILATOR
		sd_dq <= 16'bZZZZZZZZZZZZZZZZ;
`endif
		sd_cmd <= CMD_NOP;
		sd_latch <= sd_dq;

		if (!sd_ready) begin
			sd_need_refresh <= 1'b0;
			sd_last_adr <= 24'hffffff;
			sd_word <= 0;
			t <= t + 1'd1;

			if (t ==4'hF) begin 
				reset <= reset - 5'd1;
			end

			if (t == 4'h0) begin 

				if(reset == 13) begin
					$display("precharging all banks");
					sd_cmd      <= CMD_PRECHARGE;
					sd_addr[10] <= 1'b1;      // precharge all banks
				end

				if(reset == 2) begin
					sd_cmd  <= CMD_LOAD_MODE;
					sd_addr <= MODE;
				end

				if(reset == 1) begin
					$display("loading mode");
					sd_cmd  <= CMD_LOAD_MODE;
					sd_addr <= MODE;
				end

				if(reset == 0) sd_ready <= 1;
			end
		end else begin
	
			sd_refresh <= sd_refresh + 9'd1;
			if (sd_refresh == REFRESH_PERIOD) sd_need_refresh <= 1'b1;
			if(|sd_word) begin
				sd_word <= sd_word + 1'd1;
				sd_dat[sd_word[2:1]][{sd_word[0],4'b0000} +:16] <= sd_latch;
			end
			sd_req_reg <= sd_req;
			sd_cache_hit <= ~wb_we && sd_last_adr[23:4] == wb_adr[23:4];

			// this is the auto refresh code.
			// it kicks in so that 8192 auto refreshes are
			// issued in a 64ms period. Other bus operations
			// are stalled during this period.
			if (sd_need_refresh && sd_cycle == 5'd0) begin
				sd_auto_refresh <= 1'b1;
				sd_refresh      <= 10'd0;
				sd_need_refresh <= 1'b0;
				sd_cmd          <= CMD_PRECHARGE;
				sd_addr[10]     <= 1;
				sd_bank_active  <= 0;
			end else if (sd_auto_refresh) begin 
				// while the cycle is active count.
				sd_cycle <= sd_cycle + 1'd1;
				case (sd_cycle) 
				CYCLE_RFSH_START: begin
					sd_cmd <= CMD_AUTO_REFRESH;
				end
				CYCLE_RFSH_END: begin
					// reset the count.
					sd_auto_refresh <= 1'b0;
					sd_cycle <= 5'd0;
				end
				default: ;
				endcase

			end else if ((sd_cycle != 0) | (sd_cycle == 0 && sd_req_reg)) begin

				// while the cycle is active count.
				sd_cycle <= sd_cycle + 1'd1;
				case (sd_cycle)
				CYCLE_PRECHARGE: begin
					sd_we      <= wb_we;
					word_index <= 2'b00;
					if (sd_cache_hit) begin
						// this word is already in sd_dat, but where?
						word_index <= wb_adr[3:2] - sd_last_adr[3:2];
						sd_done <= ~sd_done;
						sd_cycle <= CYCLE_READ4; // allow time to de-assert wb_cyc
					end else begin
						sd_last_adr <= wb_we ? 24'hffffff : wb_adr;

						if (~sd_bank_active[sd_bank]) begin
							sd_cmd      <= CMD_ACTIVE;
							sd_addr     <= { 1'b0, sd_row };
							sd_ba       <= sd_bank;
							sd_cycle    <= CYCLE_RAS_CONT;
						end else if (sd_active_row[sd_bank] == sd_row)
							sd_cycle    <= CYCLE_CAS0;
						else begin
							sd_cmd      <= CMD_PRECHARGE;
							sd_addr[10] <= 0;
							sd_ba       <= sd_bank;
						end
					end
				end

				CYCLE_RAS_START: begin 
					sd_cmd  <= CMD_ACTIVE;
					sd_addr <= { 1'b0, sd_row };
					sd_ba   <= sd_bank;
				end

				CYCLE_RAS_CONT: begin 
					sd_active_row[sd_bank] <= sd_row;
					sd_bank_active[sd_bank] <= 1;
				end

				// this is the first CAS cycle
				CYCLE_CAS0: begin 
					// always, always read on a 32bit boundary and completely ignore the lsb of wb_adr.
					sd_addr <= { 4'b0000, wb_adr[23], wb_adr[8:2], 1'b0 };  // no auto precharge
					sd_ba   <= sd_bank;

					if (~sd_we) begin
						sd_cmd <= CMD_READ;
					end else begin
						sd_cmd  <= CMD_WRITE;
						sd_dqm  <= ~wb_sel[1:0];
`ifdef VERILATOR
						sd_q    <= wb_dat_i[15:0];
`else
						sd_dq   <= wb_dat_i[15:0];
`endif
					end
				end

				CYCLE_CAS1: begin 
					// now we access the second part of the 32 bit location.
					sd_addr <= { 4'b0000, wb_adr[23], wb_adr[8:2], 1'b1 };  // no auto precharge
					if (~sd_we) sd_dqm <= 2'b00;

					if (sd_we) begin
						sd_cmd  <= CMD_WRITE;
						sd_dqm  <= ~wb_sel[3:2];
						sd_done <= ~sd_done;
`ifdef VERILATOR
						sd_q    <= wb_dat_i[31:16];
`else
						sd_dq   <= wb_dat_i[31:16];
`endif
					end 
				end

				CYCLE_CAS2: if (~sd_we) sd_dqm <= 2'b00;

				CYCLE_READ0: begin 
					if (~sd_we) begin 
						sd_dat[0][15:0] <= sd_latch;
						sd_word <= 3'b001;
					end else 
						sd_cycle <= CYCLE_END;
				end

				CYCLE_READ1: if (~sd_we) sd_done <= ~sd_done;

				CYCLE_END: begin 
					sd_cycle <= 5'd0;
				end

				default: ;
				endcase
			end else begin
				sd_cycle <= 5'd0;
			end
		end
	end
end

reg wb_burst;
reg [1:0] wb_word;
reg [1:0] word_index;

always @(posedge wb_clk) begin 
	reg sd_doneD;

	sd_doneD <= sd_done;
	wb_ack   <= (sd_done ^ sd_doneD) & ~wb_ack;

	if (wb_stb & wb_cyc) begin 

		if ((sd_done ^ sd_doneD) & ~wb_ack) begin 
			wb_dat_o <= sd_dat[word_index];
			wb_burst <= burst_mode;
			wb_word  <= word_index + 1'd1;
		end

		if (wb_ack & wb_burst) begin 
			wb_ack   <= 1'b1;
			wb_burst <= (wb_word + 1'd1) != word_index;
			wb_word  <= wb_word + 1'd1;
			wb_dat_o <= sd_dat[wb_word];
		end

	end else begin
		wb_burst <= 1'b0;
	end
end

wire burst_mode = wb_cti == 3'b010;

// drive control signals according to current command
assign sd_cs_n  = sd_cmd[3];
assign sd_ras_n = sd_cmd[2];
assign sd_cas_n = sd_cmd[1];
assign sd_we_n  = sd_cmd[0];
assign sd_cke   = 1'b1;

endmodule
