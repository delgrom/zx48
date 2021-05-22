//-------------------------------------------------------------------------------------------------
module zx48
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire       led,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       ear,

	output wire       dsgR,
	output wire       dsgL,	

	output wire       i2sSck,
	output wire       i2sLr,
	output wire       i2sD,	

	inout  wire       keybCk,
	inout  wire       keybDQ,

	output wire       joy_clock_o       = 1'b1,
	output wire       joy_load_o        = 1'b1,
	input  wire       joy_data_i,

	output wire       sdramCk,
	output wire       sdramCe,
	output wire       sdramCs,
	output wire       sdramWe,
	output wire       sdramRas,
	output wire       sdramCas,
	output wire[ 1:0] sdramDQM,
	inout  wire[15:0] sdramDQ,
	output wire[ 1:0] sdramBA,
	output wire[12:0] sdramA,

	output wire       usdCs,
	output wire       usdCk,
	input  wire       usdMiso,
	output wire       usdMosi,
		
	output wire       stm_rst
);


`default_nettype wire

//-------------------------------------------------------------------------------------------------

assign stm_rst = 1'b0; 

wire [ 5:0] jstick1;
wire [ 5:0] jstick2;

neptuno_joydecoder  neptuno_joydecoder
(
	.clk_i           ( clock50 ),
	.joy_data_i      ( joy_data_i ),
	.joy_clk_o       ( joy_clock_o ),
	.joy_load_o      ( joy_load_o ),

	.joy1_up_o       ( jstick1[3] ),
	.joy1_down_o     ( jstick1[2] ),
	.joy1_left_o     ( jstick1[1] ),
	.joy1_right_o    ( jstick1[0] ),
	.joy1_fire1_o    ( jstick1[4] ),
	.joy1_fire2_o    ( jstick1[5] ),

	.joy2_up_o       ( jstick2[3] ),
	.joy2_down_o     ( jstick2[2] ),
	.joy2_left_o     ( jstick2[1] ),
	.joy2_right_o    ( jstick2[0] ),
	.joy2_fire1_o    ( jstick2[4] ),
	.joy2_fire2_o    ( jstick2[5] )
);

//-------------------------------------------------------------------------------------------------

clock Clock
(
	.inclk0 (clock50), // 50.000 MHz input
	.c0     (clock  ), // 56.000 MHz output
	.locked (locked )
);

reg[3:0] pw = 0;
wire power = pw[3];
always @(posedge clock) if(locked) if(!power) pw <= pw+1'd1;

reg[2:0] cc = 0;
always @(negedge clock) if(power) cc <= cc+1'd1;

wire ne28M = power & ~cc[0];
wire ne14M = power & ~cc[0] & ~cc[1];
wire ne7M0 = power & ~cc[0] & ~cc[1] & ~cc[2];

//-------------------------------------------------------------------------------------------------

wire[7:0] code;

ps2 PS2
(
	.clock  (clock  ),
	.ce     (ne7M0  ),
	.ps2Ck  (keybCk ),
	.ps2DQ  (keybDQ ),
	.kstb   (kstb   ),
	.make   (make   ),
	.code   (code   )
);

reg F5 = 1'b1;
reg F12 = 1'b1;
reg del = 1'b1;
reg alt = 1'b1;
reg ctrl = 1'b1;
reg scrlck = 1'b1;

always @(posedge clock) if(kstb)
case(code)
	8'h03: F5  <= make;
	8'h07: F12 <= make;
	8'h71: del <= make;
	8'h11: alt <= make;
	8'h14: ctrl <= make;
	8'h7E: scrlck <= make;
endcase

//-------------------------------------------------------------------------------------------------

wire reset = power & ready & F12 & (ctrl|alt|del);
wire nmi = F5;

wire[11:0] laudio;
wire[11:0] raudio;

wire[7:0] joy1 = { 3'd0, ~jstick1 };
wire[7:0] joy2 = { 2'd0, ~jstick2 };

wire[ 7:0] ramD;
wire[ 7:0] ramQ = sdrQ[7:0];
wire[17:0] ramA;

main Main
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.nmi    (nmi    ),
	.map    (map    ),
	.blank  (blank  ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.ear    (~ear   ),
	.laudio (laudio ),
	.raudio (raudio ),
	.kstb   (kstb   ),
	.make   (make   ),
	.code   (code   ),
	.joy1   (joy1   ),
	.joy2   (joy2   ),
	.cs     (usdCs  ),
	.ck     (usdCk  ),
	.miso   (usdMiso),
	.mosi   (usdMosi),
	.ramRd  (ramRd  ),
	.ramWr  (ramWr  ),
	.ramD   (ramD   ),
	.ramQ   (ramQ   ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

wire sdrRf = rfsh;
wire sdrRd = ramRd;
wire sdrWr = ramWr;

wire[15:0] sdrD = {2{ramD}};
wire[15:0] sdrQ;
wire[23:0] sdrA = { 6'd0, ramA };

sdram SDram
(
	.clock   (clock   ),
	.reset   (power   ),
	.ready   (ready   ),
	.refresh (sdrRf   ),
	.write   (sdrWr   ),
	.read    (sdrRd   ),
	.portD   (sdrD    ),
	.portQ   (sdrQ    ),
	.portA   (sdrA    ),
	.sdramCs (sdramCs ),
	.sdramRas(sdramRas),
	.sdramCas(sdramCas),
	.sdramWe (sdramWe ),
	.sdramDQM(sdramDQM),
	.sdramDQ (sdramDQ ),
	.sdramBA (sdramBA ),
	.sdramA  (sdramA  )
);

assign sdramCk = clock;
assign sdramCe = 1'b1;

//-------------------------------------------------------------------------------------------------

wire[15:0] ldata = { laudio, 3'b000 };
wire[15:0] rdata = { raudio, 3'b000 };

i2s I2S
(
	.clock  (clock  ),
	.ldata  (ldata  ),
	.rdata  (rdata  ),
	.mck    (i2sMck ),
	.sck    (i2sSck ),
	.lr     (i2sLr  ),
	.d      (i2sD   )
);

dac #(.MSBI(11)) LDac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (laudio ),
	.q      (dsgL   )
);

dac #(.MSBI(11)) RDac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (raudio ),
	.q      (dsgR   )
);

//-------------------------------------------------------------------------------------------------

reg[17:0] palette[0:15];
initial $readmemh("palette.hex", palette, 0);

wire[17:0] irgb = blank ? 1'd0 : palette[{ i, r, g, b }];
wire[17:0] orgb;

scandoubler #(.RGBW(18)) Scandoubler
(
	.clock  (clock  ),
	.ice    (ne7M0  ),
	.ihs    (hsync  ),
	.ivs    (vsync  ),
	.irgb   (irgb   ),
	.oce    (ne14M  ),
	.ohs    (ohsync ),
	.ovs    (ovsync ),
	.orgb   (orgb   )
);

reg vga = 1'b1;
reg scrlckd = 1'b1;

always @(posedge clock) if(kstb)
begin
	scrlckd <= scrlck;
	if(!scrlck && scrlckd) vga <= ~vga;
end

//-------------------------------------------------------------------------------------------------

assign led = ~usdCs;

assign sync = vga ? { ovsync, ohsync } : { 1'b1, ~(hsync^vsync) };
assign rgb = vga ? orgb : irgb;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
