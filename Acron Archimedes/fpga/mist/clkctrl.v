// megafunction wizard: %ALTCLKCTRL%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altclkctrl 

// ============================================================
// File Name: clkctrl.v
// Megafunction Name(s):
// 			altclkctrl
//
// Simulation Library Files(s):
// 			cycloneiii
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 13.1.4 Build 182 03/12/2014 Patches 4.26 SJ Web Edition
// ************************************************************


//Copyright (C) 1991-2014 Altera Corporation
//Your use of Altera Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic 
//functions, and any output files from any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Altera Program License 
//Subscription Agreement, Altera MegaCore Function License 
//Agreement, or other applicable license agreement, including, 
//without limitation, that your use is for the sole purpose of 
//programming logic devices manufactured by Altera and sold by 
//Altera or its authorized distributors.  Please refer to the 
//applicable agreement for further details.


//altclkctrl CBX_AUTO_BLACKBOX="ALL" CLOCK_TYPE="Global Clock" DEVICE_FAMILY="Cyclone III" ENA_REGISTER_MODE="falling edge" USE_GLITCH_FREE_SWITCH_OVER_IMPLEMENTATION="OFF" clkselect ena inclk outclk
//VERSION_BEGIN 13.1 cbx_altclkbuf 2014:03:12:18:15:27:SJ cbx_cycloneii 2014:03:12:18:15:29:SJ cbx_lpm_add_sub 2014:03:12:18:15:29:SJ cbx_lpm_compare 2014:03:12:18:15:29:SJ cbx_lpm_decode 2014:03:12:18:15:29:SJ cbx_lpm_mux 2014:03:12:18:15:30:SJ cbx_mgl 2014:03:12:21:10:00:SJ cbx_stratix 2014:03:12:18:15:31:SJ cbx_stratixii 2014:03:12:18:15:31:SJ cbx_stratixiii 2014:03:12:18:15:32:SJ cbx_stratixv 2014:03:12:18:15:32:SJ  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463


//synthesis_resources = clkctrl 1 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  clkctrl_altclkctrl_uhi
	( 
	clkselect,
	ena,
	inclk,
	outclk) ;
	input   [1:0]  clkselect;
	input   ena;
	input   [3:0]  inclk;
	output   outclk;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   [1:0]  clkselect;
	tri1   ena;
	tri0   [3:0]  inclk;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  wire_clkctrl1_outclk;
	wire  [1:0]  clkselect_wire;
	wire  [3:0]  inclk_wire;

	cycloneiii_clkctrl   clkctrl1
	( 
	.clkselect(clkselect_wire),
	.ena(ena),
	.inclk(inclk_wire),
	.outclk(wire_clkctrl1_outclk)
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		clkctrl1.clock_type = "Global Clock",
		clkctrl1.ena_register_mode = "falling edge",
		clkctrl1.lpm_type = "cycloneiii_clkctrl";
	assign
		clkselect_wire = {clkselect},
		inclk_wire = {inclk},
		outclk = wire_clkctrl1_outclk;
endmodule //clkctrl_altclkctrl_uhi
//VALID FILE


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module clkctrl (
	ena,
	inclk,
	outclk);

	input	  ena;
	input	  inclk;
	output	  outclk;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  ena;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  sub_wire0;
	wire [1:0] sub_wire1 = 2'h0;
	wire [2:0] sub_wire4 = 3'h0;
	wire  outclk = sub_wire0;
	wire  sub_wire2 = inclk;
	wire [3:0] sub_wire3 = {sub_wire4, sub_wire2};

	clkctrl_altclkctrl_uhi	clkctrl_altclkctrl_uhi_component (
				.clkselect (sub_wire1),
				.ena (ena),
				.inclk (sub_wire3),
				.outclk (sub_wire0));

endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone III"
// Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
// Retrieval info: PRIVATE: clock_inputs NUMERIC "1"
// Retrieval info: CONSTANT: ENA_REGISTER_MODE STRING "falling edge"
// Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone III"
// Retrieval info: CONSTANT: USE_GLITCH_FREE_SWITCH_OVER_IMPLEMENTATION STRING "OFF"
// Retrieval info: CONSTANT: clock_type STRING "Global Clock"
// Retrieval info: USED_PORT: ena 0 0 0 0 INPUT VCC "ena"
// Retrieval info: USED_PORT: inclk 0 0 0 0 INPUT NODEFVAL "inclk"
// Retrieval info: USED_PORT: outclk 0 0 0 0 OUTPUT NODEFVAL "outclk"
// Retrieval info: CONNECT: @clkselect 0 0 2 0 GND 0 0 2 0
// Retrieval info: CONNECT: @ena 0 0 0 0 ena 0 0 0 0
// Retrieval info: CONNECT: @inclk 0 0 3 1 GND 0 0 3 0
// Retrieval info: CONNECT: @inclk 0 0 1 0 inclk 0 0 0 0
// Retrieval info: CONNECT: outclk 0 0 0 0 @outclk 0 0 0 0
// Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.inc FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.cmp FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.bsf FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl_inst.v FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl_bb.v FALSE
// Retrieval info: LIB_FILE: cycloneiii
