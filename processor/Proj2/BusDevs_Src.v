module Memory(IADDR,IOUT,ABUS,RBUS,RE,WBUS,WE,CLK,LOCK,INIT);
	// File to initialize memory with
	parameter MFILE;
	// Number of bits on the ABUS
	parameter ABITS;
	// Number of bits in the address for the memory module
	// (Number of bytes in the memory module is 2^RABITS)
	parameter RABITS;
	// Number of address bits used to select byte within a word
	parameter SABITS;
	// Number of bits in a memory word
	parameter WBITS;
	// Number of bits in a byte (default is 8)
	parameter BBITS=8;
	// Number of words in memory
	parameter MWORDS=(1<<(RABITS-SABITS));

	input wire  [(ABITS-1):0] IADDR,ABUS;
	output wire [(WBITS-1):0] IOUT;
	input wire  [(WBITS-1):0] WBUS;
	inout wire  [(WBITS-1):0] RBUS;
	input wire RE,WE,CLK,LOCK,INIT;
	wire selMem=(ABUS[(ABITS-1):RABITS]=={(ABITS-RABITS){1'b0}});
	wire wrMem=WE&&selMem;
	wire rdMem=RE&&selMem;
	reg [(ABITS-1):0] oldaddr, out;
	reg [(WBITS-1):0] oldval;
	reg writ=1'b0;
	// Real memory
	(* ram_init_file = MFILE *) (* ramstyle="no_rw_check" *)
	reg [(WBITS-1):0] marray[MWORDS];
	always @(posedge CLK) if(LOCK) begin
		if(INIT) begin
		end else begin
			if(wrMem) begin
				writ <= 1'b1;
				oldaddr <= ABUS;
				oldval <= WBUS;
				marray[ABUS[(RABITS-1):SABITS]]<=WBUS;
			end
		end
	end
	always @(out or marray or rdMem or oldval or oldaddr or ABUS or RABITS or SABITS or writ) begin
		if(rdMem) begin
			out = marray[ABUS[(RABITS-1):SABITS]];
			if(writ && oldaddr == ABUS)
				out = oldval;
		end
		else
			out = {WBITS{1'bz}};
	end
	assign RBUS=out;
	assign IOUT=
		(IADDR[(ABITS-1):RABITS]=={(ABITS-RABITS){1'b0}})?
		marray[IADDR[(RABITS-1):SABITS]]:
		16'hDEAD;
endmodule

module Timer(ABUS,RBUS,RE,WBUS,WE,INTR,CLK,LOCK,INIT);
	parameter ABITS;
	parameter DBITS;
	parameter RBASE;
	parameter DIVN;
	parameter DIVB;
	input wire [(ABITS-1):0] ABUS;
	input wire [(DBITS-1):0] WBUS;
	inout wire [(DBITS-1):0] RBUS;
	input wire RE,WE,CLK,LOCK,INIT;
	output wire INTR;
	reg Rdy,Ovr,IE;
	reg [(DBITS-1):0] TRES,TCNT;
	reg [(DIVB-1):0] TDIV;
	wire [(DIVB-1):0] TDIV_next=TDIV+{{(DIVB-1){1'b0}},1'b1};
	wire [(DBITS-1):0] TCNT_next=TCNT-{{(DBITS-1){1'b0}},1'b1};
	wire selCnt=(ABUS==RBASE+4'h0);
	wire selRes=(ABUS==RBASE+4'h2);
	wire selCtl=(ABUS==RBASE+4'h4);
	wire wrCnt=WE&&selCnt;
	wire wrRes=WE&&selRes;
	wire wrCtl=WE&&selCtl;
	wire rdCnt=RE&&selCnt;
	wire rdRes=RE&&selRes;
	wire rdCtl=RE&&selCtl;
	always @(posedge CLK) if(LOCK) begin
		if(INIT) begin
			{Rdy,Ovr,IE}<=3'b000;
			TRES<={DBITS{1'b0}};
			TCNT<={DBITS{1'b0}};
		end else begin
			if(wrCtl) begin
				// Write of 1 to Rdy is ignored, so it does not appear here
				if(!WBUS[0])
					Rdy<=1'b0;
				// Write of 1 to Ovr is ignored, but write of 0 is OK
				if(!WBUS[1])
					Ovr<=1'b0;
				IE<=WBUS[4];
			end
			if(wrCnt) begin
				TCNT<=WBUS;
				TDIV<={DIVB{1'b0}};
			end else if(wrRes) begin
				TRES<=WBUS;
				if(!TCNT) begin
					TCNT<=WBUS;
					TDIV<={DIVB{1'b0}};
				end
			end else if(TCNT!={DBITS{1'b0}}) begin
				// TODO: Add code for actual counting, setting Rdy and Ovf, etc.
				if(TDIV==DIVN) begin
					if(!TCNT_next) begin
						if(Rdy)
							Ovr <= 1'b1;
						Rdy <= 1'b1;
						TCNT <= TRES;
					end
					else
						TCNT<=TCNT_next;
					TDIV<={DIVB{1'b0}};
				end
				else
					TDIV <= TDIV_next;
			end
		end
	end
	assign RBUS=rdCtl?{{(DBITS-5){1'b0}},IE,2'b0,Ovr,Rdy}:
		{DBITS{1'bz}};
	assign RBUS=rdRes?{{(DBITS-16){1'b0}},TRES}:
		{DBITS{1'bz}};
	assign RBUS=rdCnt?{{(DBITS-16){1'b0}},TCNT}:
		{DBITS{1'bz}};
	assign INTR=Rdy&&IE;
endmodule

module Display(ABUS,RBUS,RE,WBUS,WE,CLK,LOCK,INIT,HEX0,HEX1,HEX2,HEX3);
	parameter ABITS;
	parameter DBITS;
	parameter DADDR;
	input wire [(ABITS-1):0] ABUS;
	input wire [(DBITS-1):0] WBUS;
	inout wire [(DBITS-1):0] RBUS;
	input wire RE,WE,CLK,LOCK,INIT;
	output wire [6:0] HEX0,HEX1,HEX2,HEX3;
	reg [15:0] HexVal;
	SevenSeg ss3(.OUT(HEX3),.IN(HexVal[15:12]));
	SevenSeg ss2(.OUT(HEX2),.IN(HexVal[11: 8]));
	SevenSeg ss1(.OUT(HEX1),.IN(HexVal[ 7: 4]));
	SevenSeg ss0(.OUT(HEX0),.IN(HexVal[ 3: 0]));
	wire selDisp=(ABUS==DADDR);
	wire wrDisp=WE&&selDisp;
	always @(posedge CLK) if(LOCK) begin
		if(INIT)
			HexVal<=16'h0000;
		else if(wrDisp)
			HexVal<=WBUS[15:0];
	end
	wire rdDisp=RE&selDisp;
	assign RBUS=rdDisp?{{{DBITS-16}{1'b0}},HexVal}:
		{DBITS{1'bz}};
endmodule

module Leds(ABUS,RBUS,RE,WBUS,WE,CLK,LOCK,INIT,LED);
	parameter ABITS;
	parameter DBITS;
	parameter DADDR;
	parameter LBITS;
	input wire [(ABITS-1):0] ABUS;
	input wire [(DBITS-1):0] WBUS;
	inout wire [(DBITS-1):0] RBUS;
	input wire RE,WE,CLK,LOCK,INIT;
	output wire [(LBITS-1):0] LED=val;
	reg [(LBITS-1):0] val;
	wire selLED = (ABUS==DADDR);
	wire wrLED=WE&&selLED;
	always @(posedge CLK) if(LOCK) begin
	if(INIT)
		val <= {LBITS{1'b0}};
	else if(wrLED)
		val <= WBUS[(LBITS-1):0];
	end
	wire rdLED=RE&selLED;
	assign RBUS=rdLED?{{{LBITS-16}{1'b0}},val}:
		{DBITS{1'bz}};
endmodule

module KeyDev(ABUS,RBUS,RE,WBUS,WE,INTR,CLK,LOCK,INIT,KEY);
	parameter ABITS;
	parameter DBITS;
	parameter DADDR;
	parameter CADDR;
	input wire [(ABITS-1):0] ABUS;
	input wire [(DBITS-1):0] WBUS;
	inout wire [(DBITS-1):0] RBUS;
	input wire RE,WE,CLK,LOCK,INIT;
	input wire [3:0] KEY;
	output wire INTR;
	wire selData=(ABUS==DADDR);
	wire rdData=RE&&selData;
	wire selCtrl=(ABUS==CADDR);
	wire wrCtrl=WE&&selCtrl;
	wire rdCtrl=RE&&selCtrl;
	reg [3:0] prev;
	reg Rdy,Ovr,IE;
	always @(posedge CLK) if(LOCK) begin
		if(INIT) begin
			prev<=KEY;
			{Rdy,Ovr,IE}<=3'b000;
		end else begin
			// State of KEY has changed?
			if(prev!=KEY) begin
				prev <= KEY;
				if(Rdy)
					Ovr <= 1'b1;
				Rdy <= 1'b1;
			end
			// Reading DATA register?
			if(rdData) begin
				Rdy<=1'b0;
			end
			// Writing CTRL register?
			if(wrCtrl) begin
				// Write to Rdy is ignored, so it does not appear here
				// Write of 1 to Ovr is ignored, but write of 0 is OK
				if(!WBUS[1])
					Ovr<=1'b0;
				IE<=WBUS[4];
			end
		end
	end
	assign RBUS=rdData?{{(DBITS-4){1'b0}},KEY}:
		{DBITS{1'bz}};
	assign RBUS=rdCtrl?{{(DBITS-5){1'b0}},IE,2'b0,Ovr,Rdy}:
		{DBITS{1'bz}};
	assign INTR=Rdy&&IE;
endmodule

module SwDev(ABUS,RBUS,RE,WBUS,WE,INTR,CLK,LOCK,INIT,SW);
	parameter ABITS;
	parameter DBITS;
	parameter DADDR;
	parameter CADDR;
	input wire [(ABITS-1):0] ABUS;
	input wire [(DBITS-1):0] WBUS;
	inout wire [(DBITS-1):0] RBUS;
	input wire RE,WE,CLK,LOCK,INIT;
	// Number of bits in the debounce counter
	parameter DEBB;
	// Value for the debounce counter (# of CLK ticks in 10ms)
	parameter DEBN;
	input wire [9:0] SW;
	reg [9:0] prev, val;
	output wire INTR;
	wire selData=(ABUS==DADDR);
	wire rdData=RE&&selData;
	wire selCtrl=(ABUS==CADDR);
	wire wrCtrl=WE&&selCtrl;
	wire rdCtrl=RE&&selCtrl;
	reg Rdy,Ovr,IE;
	// TODO: This should be similar to KeyDev, but you must first
	// debounce for 10ms (see slides) before a change in SW affects Rdy
	reg [DEBB:0] counter;
	always @(posedge CLK) if(LOCK) begin
		if(INIT) begin
			counter <= {DEBB{1'b0}};
			prev <= SW;
			val <= SW;
			{Rdy,Ovr,IE}<=3'b000;
		end
		else begin
			if(prev != val) begin
				if(!counter) begin
					val <= prev;
					if(Rdy)
						Ovr <= 1'b1;
					Rdy <= 1'b1;
				end
				else
					counter <= counter - 1'b1;
			end
			else if(prev != SW) begin
				counter <= DEBN;
				prev <= SW;
			end
			// Reading DATA register?
			if(rdData) begin
				Rdy<=1'b0;
			end
			// Writing CTRL register?
			if(wrCtrl) begin
				// Write to Rdy is ignored, so it does not appear here
				// Write of 1 to Ovr is ignored, but write of 0 is OK
				if(!WBUS[1])
					Ovr<=1'b0;
				IE<=WBUS[4];
			end
		end
	end
	assign RBUS=rdData?{{(DBITS-10){1'b0}},val}:
		{DBITS{1'bz}};
	assign RBUS=rdCtrl?{{(DBITS-5){1'b0}},IE,2'b0,Ovr,Rdy}:
		{DBITS{1'bz}};
	assign INTR=Rdy&&IE;
endmodule
