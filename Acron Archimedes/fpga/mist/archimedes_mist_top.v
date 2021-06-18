`timescale 1ns / 1ps
// archimedes_mist_top.v
//
// Archimedes Mist Support Top
//
// Copyright (c) 2014-2015 Stephen J. Leary <sleary@vavi.co.uk>
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
module archimedes_mist_top(
	// clock inputs
	input   [1:0] CLOCK_27, // 27 MHz
	// LED outputs
	output        LED, // LED Yellow
	// UART
	//output      UART_TX, // UART Transmitter
	//input       UART_RX, // UART Receiver
  
	// VGA
	output        VGA_HS, // VGA H_SYNC
	output        VGA_VS, // VGA V_SYNC
	output  [5:0] VGA_R, // VGA Red[5:0]
	output  [5:0] VGA_G, // VGA Green[5:0]
	output  [5:0] VGA_B, // VGA Blue[5:0];
	
	// AUDIO
	output        AUDIO_L, // sigma-delta DAC output left
	output        AUDIO_R, // sigma-delta DAC output right
	
	// SDRAM
	output [12:0] DRAM_A,
	output  [1:0] DRAM_BA,
	output        DRAM_CAS_N,
	output        DRAM_CKE,
	output        DRAM_CLK,
	output        DRAM_CS_N,
	inout  [15:0] DRAM_DQ,
	output  [1:0] DRAM_DQM,
	output        DRAM_RAS_N,
	output        DRAM_WE_N,
  
	// SPI
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SCK,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         SPI_SS4,    // Direct SD
	input         CONF_DATA0  // SPI_SS for user_io
);

wire [7:0] kbd_out_data;
wire kbd_out_strobe;
wire [7:0] kbd_in_data;
wire kbd_in_strobe;

// generated clocks
wire clk_pix, clk_pix_i;
wire clk_vid, clk_vid_i;
wire ce_pix;
wire clk_sys /* synthesis keep */ ;
wire clk_mem /* synthesis keep */ ;
//wire clk_8m  /* synthesis keep */ ;

wire pll_ready;
wire pll_vidc_ready;
wire ram_ready;

// core's raw video 
wire [3:0] core_r, core_g, core_b;
wire       core_hs, core_vs;

// core's raw audio 
wire [15:0] coreaud_l, coreaud_r;

// data loading 
wire       downloading, uploading;
wire       loader_active = downloading && (dio_index == 1 || dio_index == 2);
wire [7:0] dio_index;
wire       loader_we /* synthesis keep */ ;
reg        loader_stb = 1'b0 /* synthesis keep */ ;
reg        rom_ready = 0;
(*KEEP="TRUE"*)wire [3:0]	loader_sel /* synthesis keep */ ;
(*KEEP="TRUE"*)wire [23:0]	loader_addr /* synthesis keep */ ;
(*KEEP="TRUE"*)wire [31:0]	loader_dout /* synthesis keep */ ;
wire [7:0] loader_din;
          
// user io

wire [7:0] joyA;
wire [7:0] joyB;
wire [1:0] buttons;
wire [1:0] switches;
wire       scandoubler_disable;
wire       ypbpr;
wire       no_csync;
wire[63:0] rtc;

// the top file should generate the correct clocks for the machine

clockgen CLOCKS(
	.inclk0	(CLOCK_27[0]),
	.c0		(DRAM_CLK),// 120 MHz, shifted
	.c1		(clk_mem), // 120 MHz
	.c2      (clk_sys), // 40 MHz
	.locked	(pll_ready)  // pll locked output
);

reg [3:0] clken_counter;
reg       clk8m_en;
reg       clk2m_en;

always @(posedge clk_sys) begin
	clken_counter <= clken_counter + 1'd1;
	if (clken_counter == 19) clken_counter <= 0;

	clk2m_en <= clken_counter ==  0;
	clk8m_en <= clken_counter ==  0 || clken_counter ==  5 || clken_counter == 10 || clken_counter == 15;
end

pll_vidc_36 CLOCKS_VIDC(
	.inclk0	(clk_sys),
	.c0     (clk_pix_i), // 2x VIDC pixel clock (48, 50, 76 MHz);
	.c1     (clk_vid_i), // 4x VIDC pixel clock for scandoubler use (24MHz mode => 96 MHz), otherwise 2x pixel clock
	.areset(pll_areset),
	.scanclk(pll_scanclk),
	.scandata(pll_scandata),
	.scanclkena(pll_scanclkena),
	.configupdate(pll_configupdate),
	.scandataout(pll_scandataout),
	.scandone(pll_scandone),
	.locked	(pll_vidc_ready)  // pll locked output
);

reg        vidc_clock_ena;

clkctrl CLKCTRL_PIX(
	.inclk(clk_pix_i),
	.outclk(clk_pix),
	.ena(vidc_clock_ena)
);

clkctrl CLKCTRL_VID(
	.inclk(clk_vid_i),
	.outclk(clk_vid),
	.ena(vidc_clock_ena)
);

wire       pll_reconfig_busy;
wire       pll_areset;
wire       pll_configupdate;
wire       pll_scanclk;
wire       pll_scanclkena;
wire       pll_scandata;
wire       pll_scandataout;
wire       pll_scandone;
reg        pll_reconfig_reset;
wire [7:0] pll_rom_address;
wire       pll_rom_q;
reg        pll_write_from_rom;
wire       pll_write_rom_ena;
reg        pll_reconfig;
wire       q_reconfig_25;
wire       q_reconfig_24;
wire       q_reconfig_36;

rom_reconfig_25 rom_reconfig_25
(
	.address(pll_rom_address),
	.clock(clk_sys),
	.rden(pll_write_rom_ena),
	.q(q_reconfig_25)
);

rom_reconfig_24 rom_reconfig_24
(
	.address(pll_rom_address),
	.clock(clk_sys),
	.rden(pll_write_rom_ena),
	.q(q_reconfig_24)
);

rom_reconfig_36 rom_reconfig_36
(
	.address(pll_rom_address),
	.clock(clk_sys),
	.rden(pll_write_rom_ena),
	.q(q_reconfig_36)
);

assign pll_rom_q = pixbaseclk_select == 2'b01 ? q_reconfig_25 :
                   pixbaseclk_select == 2'b10 ? q_reconfig_36 : q_reconfig_24;

pll_reconfig pll_reconfig_inst
(
	.busy(pll_reconfig_busy),
	.clock(clk_sys),
	.counter_param(0),
	.counter_type(0),
	.data_in(0),
	.pll_areset(pll_areset),
	.pll_areset_in(0),
	.pll_configupdate(pll_configupdate),
	.pll_scanclk(pll_scanclk),
	.pll_scanclkena(pll_scanclkena),
	.pll_scandata(pll_scandata),
	.pll_scandataout(pll_scandataout),
	.pll_scandone(pll_scandone),
	.read_param(0),
	.reconfig(pll_reconfig),
	.reset(pll_reconfig_reset),
	.reset_rom_address(0),
	.rom_address_out(pll_rom_address),
	.rom_data_in(pll_rom_q),
	.write_from_rom(pll_write_from_rom),
	.write_param(0),
	.write_rom_ena(pll_write_rom_ena)
);

always @(posedge clk_sys) begin
	reg [1:0] pixbaseclk_select_d = 2'b10;
	reg [1:0] pll_reconfig_state = 0;
	reg [9:0] pll_reconfig_timeout;

	pll_write_from_rom <= 0;
	pll_reconfig <= 0;
	pll_reconfig_reset <= 0;
	case (pll_reconfig_state)
	2'b00:
	begin
		vidc_clock_ena <= 1;
		pixbaseclk_select_d <= pixbaseclk_select;
		if (pixbaseclk_select_d != pixbaseclk_select) begin
			vidc_clock_ena <= 0;
			pll_write_from_rom <= 1;
			pll_reconfig_state <= 2'b01;
		end
	end
	2'b01: pll_reconfig_state <= 2'b10;
	2'b10:
        if (~pll_reconfig_busy) begin
            pll_reconfig <= 1;
            pll_reconfig_state <= 2'b11;
            pll_reconfig_timeout <= 10'd1000;
        end
	2'b11:
	begin
		pll_reconfig_timeout <= pll_reconfig_timeout - 1'd1;
		if (pll_reconfig_timeout == 10'd1) begin
			// pll_reconfig stuck in busy state
			pll_reconfig_reset <= 1;
			pll_reconfig_state <= 2'b00;
		end
		if (~pll_reconfig & ~pll_reconfig_busy) pll_reconfig_state <= 2'b00;
	end
	default: ;
	endcase
end

// forcibly blank back porch area
reg [3:0] r_adj, g_adj, b_adj;
reg       hs_adj, vs_adj;
reg [7:0] pix_cnt;
// blanking size: 256 cycles @ 24MHz (TV), 64 cycles otherwise (VGA)
wire      back_porch_n =  (pixbaseclk_select[0] == pixbaseclk_select[1]) ? &pix_cnt : &pix_cnt[5:0];

always @(posedge clk_pix) begin

	if (~back_porch_n) pix_cnt <= pix_cnt + 1'd1;
	if (~hs_adj) pix_cnt <= 0;

	if (ce_pix) begin
		hs_adj <= core_hs;
		vs_adj <= core_vs;

		if (back_porch_n) begin
			r_adj <= core_r;
			g_adj <= core_g;
			b_adj <= core_b;
		end else
			{ r_adj, g_adj, b_adj } <= 12'h0;
	end
end

wire   scandoubler_en = ~scandoubler_disable && pixbaseclk_select[0] == pixbaseclk_select[1];

mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(12)) mist_video (
	.clk_sys     ( clk_vid    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( 2'b00      ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b1       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( ~scandoubler_en ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( r_adj      ),
	.G           ( g_adj      ),
	.B           ( b_adj      ),

	.HSync       ( hs_adj     ),
	.VSync       ( vs_adj     ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_conf;
wire        sd_sdhc = 1'b1;
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire        sd_din_strobe;
wire  [8:0] sd_buff_addr;
wire  [1:0] img_mounted;
wire [31:0] img_size;

// de-multiplex spi outputs from user_io and data_io
assign SPI_DO = (CONF_DATA0==0)?user_io_sdo:(SPI_SS2==0)?data_io_sdo:1'bZ;

wire user_io_sdo;
user_io user_io(
	// the spi interface
	.clk_sys        ( clk_sys        ),
	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( user_io_sdo    ),   // tristate handling inside user_io
	.SPI_MOSI       ( SPI_DI         ),

	.SWITCHES       ( switches       ),
	.BUTTONS        ( buttons        ),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr          ( ypbpr          ),
	.no_csync       ( no_csync       ),
	.rtc            ( rtc            ),

	.JOY0           ( joyA           ),
	.JOY1           ( joyB           ),

	.kbd_out_data   ( kbd_out_data   ),
	.kbd_out_strobe ( kbd_out_strobe ),
	.kbd_in_data    ( kbd_in_data    ),
	.kbd_in_strobe  ( kbd_in_strobe  ),

	.sd_lba         ( sd_lba         ),
	.sd_rd          ( sd_rd          ),
	.sd_wr          ( sd_wr          ),
	.sd_ack         ( sd_ack         ),
	.sd_ack_conf    ( sd_ack_conf    ),
	.sd_conf        ( sd_conf        ),
	.sd_sdhc        ( sd_sdhc        ),
	.sd_dout        ( sd_dout        ),
	.sd_dout_strobe ( sd_dout_strobe ),
	.sd_din         ( sd_din         ),
	.sd_din_strobe  ( sd_din_strobe  ),
	.sd_buff_addr   ( sd_buff_addr   ),
	.img_mounted    ( img_mounted    ),
	.img_size       ( img_size       )
);

wire   spi_din = SPI_SS4 ? SPI_DI : SPI_DO;

wire data_io_sdo;
data_io # ( .START_ADDR(24'h40_0000) )
DATA_IO  (
	.sck            ( SPI_SCK        ),
	.ss             ( SPI_SS2        ),
	.ss_sd          ( SPI_SS4        ),
	.sdi            ( spi_din        ),
	.sdo            ( data_io_sdo    ),

	.ide_cmd_req    ( ide_cmd_req    ),
	.ide_dat_req    ( ide_dat_req    ),
	.ide_status     ( ide_status     ),
	.ide_status_wr  ( ide_status_wr  ),
	.ide_reg_o_adr  ( ide_reg_i_adr  ),
	.ide_reg_o      ( ide_reg_i      ),
	.ide_reg_we     ( ide_reg_we     ),
	.ide_reg_i_adr  ( ide_reg_o_adr  ),
	.ide_reg_i      ( ide_reg_o      ),
	.ide_data_addr  ( ide_data_addr  ),
	.ide_data_o     ( ide_data_i     ),
	.ide_data_i     ( ide_data_o     ),
	.ide_data_rd    ( ide_data_rd    ),
	.ide_data_we    ( ide_data_we    ),

	.downloading    ( downloading    ),
	.uploading      ( uploading      ),
	.index          ( dio_index      ),

	// ram interface
	.clk           ( clk_sys         ),
	.wr            ( loader_we       ),
	.a             ( loader_addr     ),
	.sel           ( loader_sel      ),
	.dout          ( loader_dout     ),
	.din           ( loader_din      )
);

wire        core_ack_in   /* synthesis keep */ ;
wire        core_stb_out  /* synthesis keep */ ;
wire        core_cyc_out  /* synthesis keep */ ;
wire        core_we_o;
wire  [3:0] core_sel_o;
wire  [2:0] core_cti_o;
wire [31:0] core_data_in, core_data_out;
wire [31:0] ram_data_in;
wire [26:2] core_address_out;

wire  [1:0] pixbaseclk_select;

wire        i2c_din, i2c_dout, i2c_clock;

wire        ide_cmd_req;
wire        ide_dat_req;
wire  [7:0] ide_status;
wire        ide_status_wr;
wire  [2:0] ide_reg_o_adr;
wire  [7:0] ide_reg_o;
wire        ide_reg_we;
wire  [2:0] ide_reg_i_adr;
wire  [7:0] ide_reg_i;
wire  [8:0] ide_data_addr;
wire  [7:0] ide_data_o;
wire  [7:0] ide_data_i;
wire        ide_data_rd;
wire        ide_data_we;

wire        reset = ~ram_ready | ~rom_ready | buttons[1];

archimedes_top ARCHIMEDES(
	
	.CLKCPU_I       ( clk_sys        ),
	.CLKPIX_I       ( clk_pix        ), // 2xVIDC clock
	.CEPIX_O        ( ce_pix         ),
	.CLK2M_EN       ( clk2m_en       ),
	.CLK8M_EN       ( clk8m_en       ),

	.RESET_I        ( reset          ),

	.MEM_ACK_I      ( core_ack_in    ),
	.MEM_DAT_I      ( core_data_in   ),
	.MEM_DAT_O      ( core_data_out  ),
	.MEM_ADDR_O     ( core_address_out ),
	.MEM_STB_O      ( core_stb_out   ),
	.MEM_CYC_O      ( core_cyc_out   ),
	.MEM_SEL_O      ( core_sel_o     ),
	.MEM_WE_O       ( core_we_o      ),
	.MEM_CTI_O      ( core_cti_o     ),

	.HSYNC          ( core_hs        ),
	.VSYNC          ( core_vs        ),

	.VIDEO_R        ( core_r         ),
	.VIDEO_G        ( core_g         ),
	.VIDEO_B        ( core_b         ),

	.AUDIO_L        ( coreaud_l      ),
	.AUDIO_R        ( coreaud_r      ),

	.I2C_DOUT       ( i2c_din        ),
	.I2C_DIN        ( i2c_dout       ),
	.I2C_CLOCK      ( i2c_clock      ),

	.DEBUG_LED      ( LED            ),

	// FDC connection
	.img_mounted    ( img_mounted    ),
	.img_size       ( img_size       ),
	.img_wp         ( 0              ),
	.sd_lba         ( sd_lba         ),
	.sd_rd          ( sd_rd          ),
	.sd_wr          ( sd_wr          ),
	.sd_ack         ( sd_ack         ),
	.sd_buff_addr   ( sd_buff_addr   ),
	.sd_dout        ( sd_dout        ),
	.sd_din         ( sd_din         ),
	.sd_dout_strobe ( sd_dout_strobe ),

	// IDE controller
	.ide_cmd_req    ( ide_cmd_req    ),
	.ide_dat_req    ( ide_dat_req    ),
	.ide_status     ( ide_status     ),
	.ide_status_wr  ( ide_status_wr  ),
	.ide_reg_o_adr  ( ide_reg_o_adr  ),
	.ide_reg_o      ( ide_reg_o      ),
	.ide_reg_we     ( ide_reg_we     ),
	.ide_reg_i_adr  ( ide_reg_i_adr  ),
	.ide_reg_i      ( ide_reg_i      ),
	.ide_data_addr  ( ide_data_addr  ),
	.ide_data_o     ( ide_data_o     ),
	.ide_data_i     ( ide_data_i     ),
	.ide_data_rd    ( ide_data_rd    ),
	.ide_data_we    ( ide_data_we    ),

	.KBD_OUT_DATA   ( kbd_out_data   ),
	.KBD_OUT_STROBE ( kbd_out_strobe ),
	.KBD_IN_DATA    ( kbd_in_data    ),
	.KBD_IN_STROBE  ( kbd_in_strobe  ),

	.JOYSTICK0      ( ~{joyB[4], joyB[0], joyB[1], joyB[2], joyB[3]} ),
	.JOYSTICK1      ( ~{joyA[4], joyA[0], joyA[1], joyA[2], joyA[3]} ),
	.VIDBASECLK_O	( pixbaseclk_select ),
	.VIDSYNCPOL_O	( )
);

wire        ram_ack     /* synthesis keep */ ;
wire        ram_stb     /* synthesis keep */ ;
wire        ram_cyc     /* synthesis keep */ ;
wire        ram_we      /* synthesis keep */ ;
wire  [3:0] ram_sel     /* synthesis keep */ ;
wire [25:0] ram_address /* synthesis keep */ ;

sdram_top SDRAM(

	// wishbone interface
	.wb_clk         ( clk_sys        ),
	.wb_stb         ( ram_stb        ),
	.wb_cyc         ( ram_cyc        ),
	.wb_we          ( ram_we         ),
	.wb_ack         ( ram_ack        ),

	.wb_sel         ( ram_sel        ),
	.wb_adr         ( ram_address    ),
	.wb_dat_i       ( ram_data_in    ),
	.wb_dat_o       ( core_data_in   ),
	.wb_cti	        ( core_cti_o     ),

	// SDRAM Interface
	.sd_clk         ( clk_mem        ),
	.sd_rst         ( ~pll_ready     ),
	.sd_cke         ( DRAM_CKE       ),

	.sd_dq          ( DRAM_DQ        ),
	.sd_addr        ( DRAM_A         ),
	.sd_dqm         ( DRAM_DQM       ),
	.sd_cs_n        ( DRAM_CS_N      ),
	.sd_ba          ( DRAM_BA        ),
	.sd_we_n        ( DRAM_WE_N      ),
	.sd_ras_n       ( DRAM_RAS_N     ),
	.sd_cas_n       ( DRAM_CAS_N     ),
	.sd_ready	( ram_ready      )
);

i2cSlaveTop CMOS (
	.clk            ( clk_sys        ),
	.rst            ( ~pll_ready     ),
	.sdaIn          ( i2c_din        ),
	.sdaOut	        ( i2c_dout       ),
	.scl            ( i2c_clock      ),
	.we             ( downloading && dio_index == 3 && loader_we ),
	.rd             ( uploading && dio_index == 3),
	.addr           ( loader_addr[7:0] ),
	.din            ( loader_dout[7:0] ),
	.dout           ( loader_din ),
	.RTC            ( rtc            )
);

audio	AUDIO	(
	.clk            ( clk_pix        ),
	.rst            ( ~pll_ready     ),
	.audio_data_l   ( coreaud_l      ),
	.audio_data_r   ( coreaud_r      ),
	.audio_l        ( AUDIO_L        ),
	.audio_r        ( AUDIO_R        )
);

always @(posedge clk_sys) begin 
	reg loader_active_old;
	loader_active_old <= loader_active;

	if (loader_active_old & ~loader_active) rom_ready <= 1;
	if (loader_we) begin 

		loader_stb <= 1'b1;

	end else if (ram_ack) begin 

		loader_stb <= 1'b0;

	end

end

assign ram_we       = loader_active ? loader_active : core_we_o;
assign ram_sel      = loader_active ? loader_sel : core_sel_o;
assign ram_address  = loader_active ? {loader_addr[23:2],2'b00} : {core_address_out[23:2],2'b00};
assign ram_stb      = loader_active ? loader_stb : core_stb_out;
assign ram_cyc      = loader_active ? loader_stb : core_stb_out;
assign ram_data_in  = loader_active ? loader_dout : core_data_out;
assign core_ack_in  = loader_active ? 1'b0 : ram_ack;

endmodule // archimedes_mist_top
