//
// ide.sv
//
// Copyright (c) 2019 György Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module ide (
	input             clk, // system clock.
	input             reset,

	input             ide_sel,
	input             ide_we,
	input       [2:0] ide_reg,
	input      [15:0] ide_dat_i,
	output reg [15:0] ide_dat_o,

	// place any signals that need to be passed up to the top after here.
	output            ide_cmd_req,
	output            ide_dat_req,
	input       [7:0] ide_status,
	input             ide_status_wr,

	input       [2:0] ide_reg_o_adr,
	output reg  [7:0] ide_reg_o,
	input             ide_reg_we,
	input       [2:0] ide_reg_i_adr,
	input       [7:0] ide_reg_i,

	input       [8:0] ide_data_addr,
	output      [7:0] ide_data_o,
	input       [7:0] ide_data_i,
	input             ide_data_rd,
	input             ide_data_we
);

reg [7:0] taskfile[8];
wire [7:0] status = {bsy,drdy,2'b00,drq,2'b00,err} /* synthesis keep */;

// HDD status register bits
wire bsy = busy & ~drq;
wire drdy = ~(bsy|drq);
wire err = error;
wire drq /* synthesis keep */;

reg  busy;
reg  pio_in, pio_out;
reg  error;

wire sel_cmd = ide_sel && ide_we && ide_reg == 3'd7;

// read from Task File Registers
always @(*) begin
	reg [7:0] ide_dat_b;
	//cpu read
	ide_dat_b = (ide_reg == 3'd7) ? status : taskfile[ide_reg];
	ide_dat_o = 16'hFFFF;
	if (ide_sel && !ide_we) begin
		ide_dat_o = (ide_reg == 3'd0) ? data_out : { ide_dat_b, ide_dat_b };
	end

	// IO controller read
	ide_reg_o  = taskfile[ide_reg_o_adr];
end

// write to Task File Registers
always @(posedge clk) begin
	if (reset) begin
		busy <= 0;
	end else begin
		// cpu write
		if (ide_sel && ide_we) begin
			taskfile[ide_reg] <= ide_dat_i[7:0];
			// writing to the command register triggers the IO controller
			if (ide_reg == 3'd7) busy <= 1;
		end

		if ((ide_status_wr && ide_status[7]) || (sector_count_dec && pio_in && sector_count == 8'h01)) busy <= 0;

		// IO controller write
		if (ide_reg_we) taskfile[ide_reg_i_adr] <= ide_reg_i;
	end
end

// pio in command type
always @(posedge clk)
	if (reset)
		pio_in <= 0;
	else if (drdy) // reset when processing of the current command ends
		pio_in <= 0;
	else if (busy && ide_status_wr && ide_status[3]) // set by SPI host
		pio_in <= 1;

// pio out command type
always @(posedge clk)
	if (reset)
		pio_out <= 0;
	else if (busy && ide_status_wr && ide_status[7]) // reset by SPI host when command processing completes
		pio_out <= 0;
	else if (busy && ide_status_wr && ide_status[2]) // set by SPI host
		pio_out <= 1;

// error status
always @(posedge clk)
	if (reset)
		error <= 0;
	else if (sel_cmd) // reset by the CPU when command register is written
		error <= 0;
	else if (busy && ide_status_wr && ide_status[0]) // set by SPI host
		error <= 1;

assign drq = (fifo_full & pio_in) | (~fifo_full & pio_out & sector_count != 0); // HDD data request status bit
assign ide_cmd_req = bsy; // bsy is set when command register is written, tells the SPI host about new command
assign ide_dat_req = (fifo_full && pio_out); // the FIFO is full so SPI host may read it

// sector count
reg  [7:0] sector_count;
wire       sector_count_dec = sector_count != 0 && ide_sel_d && ~ide_sel && ide_reg == 3'd0 && data_addr == 8'hff;

always @(posedge clk)
	if (sel_cmd)
		sector_count <= taskfile[2];
	else if (sector_count_dec)
		sector_count <= sector_count - 1'd1;

reg   [7:0] data_addr;
wire [15:0] data_out;
reg         ide_sel_d;

// read/write data register
always @(posedge clk) begin
	ide_sel_d <= ide_sel;
	if (sel_cmd) data_addr <= 0;
	if (ide_sel_d && ~ide_sel && ide_reg == 3'd0) data_addr <= data_addr + 1'd1;
end

reg         fifo_full;
always @(posedge clk) begin
	if (reset)
		fifo_full <= 0;
	else if (sel_cmd)
		fifo_full <= 0;
	else if (pio_in) begin // reads
		if (ide_data_we && ide_data_addr == 9'h1FF) fifo_full <= 1; // full when the IO controller wrote the last byte
		else if (ide_sel_d && ~ide_sel && ide_reg == 3'd0 && data_addr == 8'hFF) fifo_full <= 0; // not full when the CPU read the last word
	end else if (pio_out) begin // writes
		if (ide_sel_d && ~ide_sel && ide_reg == 3'd0 && data_addr == 8'hFF) fifo_full <= 1; // full when the CPU wrote the last word
		else if (ide_data_rd && ide_data_addr == 9'h1FF) fifo_full <= 0; // not full when the IO controller read the last word
	end
end

// mixed-width sector buffer
ide_dpram ide_databuf (
	.clock     ( clk            ),

	.address_a ( data_addr      ),
	.data_a    ( ide_dat_i      ),
	.wren_a    ( ide_sel && ide_we && ide_reg == 3'd0 ),
	.q_a       ( data_out       ),

	.address_b ( ide_data_addr  ),
	.data_b    ( ide_data_i     ),
	.wren_b    ( ide_data_we    ),
	.q_b       ( ide_data_o     )
);

endmodule


module ide_dpram
(
	input             clock,

	input       [7:0] address_a,
	input      [15:0] data_a,
	input             wren_a,
	output reg [15:0] q_a,

	input       [8:0] address_b,
	input       [7:0] data_b,
	input             wren_b,
	output reg  [7:0] q_b
);

reg [1:0][7:0] ram[256];

always @(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always @(posedge clock) begin
	if(wren_b) begin
		ram[address_b[8:1]][address_b[0]] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b[8:1]][address_b[0]];
	end
end

endmodule
