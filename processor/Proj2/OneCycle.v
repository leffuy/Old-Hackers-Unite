module OneCycle(SW,KEY,LEDR,LEDG,HEX0,HEX1,HEX2,HEX3,CLOCK_50); 
	input  [9:0] SW;
	input  [3:0] KEY;
	input  CLOCK_50;
	output [9:0] LEDR;
	output [7:0] LEDG;
	output [6:0] HEX0,HEX1,HEX2,HEX3;

	wire [6:0] digit0,digit1,digit2,digit3;
	wire [7:0] ledgreen;
	wire [9:0] ledred;

	// Warning: The file you submit for Project 1 must use a PLL with a 50% duty cycle
	wire clk,lock;
	OneCycPll oneCycPll(.inclk0(CLOCK_50),.c0(clk),.locked(lock));
	//wire clk = KEY[0];
	//wire clk = CLOCK_50;
	//wire lock = 1'b1;
	wire [3:0] keys=KEY;
	wire [9:0] switches=SW;
	//assign LEDR = opcode1;

	assign {HEX0,HEX1,HEX2,HEX3,LEDR,LEDG}={digit0,digit1,digit2,digit3,ledred,ledgreen};
	parameter DBITS=16;

	reg [(DBITS-1):0] PC=16'h200,nextPC;
	always @(posedge clk)
		if(lock)
			PC <= nextPC;
	wire [(DBITS-1):0] pcplus=PC+16'd2;
	reg [(DBITS-1):0] pcplus_A, pcplus_M;
	always @(posedge clk) begin
		pcplus_A <= pcplus;
		pcplus_M <= pcplus_A;
	end

	// These are connected to the memory module
	wire [(DBITS-1):0] imemaddr=PC;
	wire [(DBITS-1):0] imemout;

	wire [(DBITS-1):0] inst=imemout;
	wire [2:0] opcode1=inst[15:13];
	reg [2:0] opcode1_A, opcode1_M;

	always @(posedge clk) begin
		opcode1_A <= opcode1;
		opcode1_M <= opcode1_A;
		if(flush) begin
			opcode1_A <= 3'b111;
			opcode1_M <= 3'b111;
		end
	end

	// Provide nice names for opcode1 values
	parameter
		OP1_ALU =3'b000,
		OP1_ADDI=3'b001,
		OP1_BEQ =3'b010,
		OP1_BNE =3'b011,
		OP1_LW  =3'b100,
		OP1_SW  =3'b101,
		OP1_JMP =3'b110;
	// Provide nice names for opcode2 values when opcode1==OP1_ALU
	parameter
		ALU_OP2_ADD = 4'b0000,
		ALU_OP2_SUB = 4'b0001,
		ALU_OP2_LT  = 4'b0100,
		ALU_OP2_LE  = 4'b0101,
		ALU_OP2_AND = 4'b1000,
		ALU_OP2_OR  = 4'b1001,
		ALU_OP2_XOR = 4'b1010,
		ALU_OP2_NAND= 4'b1100,
		ALU_OP2_NOR = 4'b1101,
		ALU_OP2_NXOR= 4'b1110;
	// Provide nice names for ALU control
	parameter
		ALU_ADD  = ALU_OP2_ADD,
		ALU_SUB  = ALU_OP2_SUB,
		ALU_LT   = ALU_OP2_LT,
		ALU_LE   = ALU_OP2_LE,
		ALU_AND  = ALU_OP2_AND,
		ALU_OR   = ALU_OP2_OR,
		ALU_XOR  = ALU_OP2_XOR,
		ALU_NAND = ALU_OP2_NAND,
		ALU_NOR  = ALU_OP2_NOR,
		ALU_NXOR = ALU_OP2_NXOR;
	 

	wire [2:0] rsrc1  =inst[12:10];
	wire [2:0] rsrc2  =inst[ 9: 7];
	wire [2:0] rdst   =inst[ 6: 4];

	wire [3:0] opcode2=inst[ 3: 0];
	parameter IMMBITS=7;
	wire [(IMMBITS-1):0] imm=inst[(IMMBITS-1): 0];
	wire [(DBITS-1):0]   dimm={{(DBITS-IMMBITS){imm[IMMBITS-1]}},imm};
	wire [(DBITS-1):0]   bimm={{(DBITS-IMMBITS-1){imm[IMMBITS-1]}},imm,1'b0};
	reg immsig, immsig_A, flush, flushsig;
	always @(posedge clk)
		immsig_A <= immsig;

	wire [(DBITS-1):0] pctarg= pcplus+bimm;

	// The rregno1 and rregno2 always come from rsrc1 and rsrc2 field in the instruction word
	wire [2:0] rregno1=rsrc1, rregno2=rsrc2;
	reg [2:0] rregno1_A, rregno2_A;
	wire [(DBITS-1):0] regout1, regout2;
	reg [(DBITS-1):0] rregout1, rregout2, regout1_A, regout2_A, regout1_M, regout2_M, jmptarg; 
	// These three are optimized-out "reg" (control logic uses an always-block)
	// But wregno may come from rsrc2 or rdst fields (decided by control logic)
	reg [2:0] wregno, wregno_A, wregno_M;
	reg wrreg, wrreg_A, wrreg_M;
	reg [(DBITS-1):0] wregval_M;
	RegFile #(.DBITS(DBITS),.ABITS(3),.MFILE("Regs.mif")) regFile(
		.RADDR1(rregno1),.DOUT1(regout1),
		.RADDR2(rregno2),.DOUT2(regout2),
		.WADDR(wregno_M),.DIN(wregval_M),
		.WE(wrreg_M),.CLK(clk));
	
	always @(posedge clk) begin
		wrreg_A <= wrreg;
		wregno_A <= wregno;
		wregno_M <= wregno_A;
		wrreg_M <= wrreg_A;

		rregno1_A <= rregno1;
		rregno2_A <= rregno2;

		regout1_M <= rregout1;
		regout2_M <= rregout2;

		if(flush) begin
			wrreg_A <= 1'b0;
			wrreg_M <= 1'b0;
		end
	end
	
	always @(posedge clk) begin
		regout1_A <= regout1;
		regout2_A <= regout2;
		if(wrreg_M) begin
			if(rregno1 == wregno_M)
				regout1_A <= wregval_M;
			if(rregno2 == wregno_M)
				regout2_A <= wregval_M;
		end
	end

	always @(rregno1_A or rregno2_A or rregout1 or rregout2 or regout1 or regout2 or wrreg_M or wregno_M or wregval_M or regout1_A or regout2_A) begin
		rregout1 = regout1_A;
		rregout2 = regout2_A;
		if(wrreg_M) begin
			if(rregno1_A == wregno_M)
				rregout1 = wregval_M;
			if(rregno2_A == wregno_M)
				rregout2 = wregval_M;
		end
	end
/*	
	always @(rregno1 or regout1 or regout2 or rregno2 or wrreg_A or wregno_A or opcode1_A or aluout or jmptarg or wrreg_M or wregno_M or wregval_M) begin
		jmptarg = regout1;
		if(wrreg_M) begin
			if(rregno1 == wregno_M)
				jmptarg = wregval_M;
		end
		if(wrreg_A) begin
			if(rregno1 == wregno_A)
				jmptarg = aluout;
		end
	end
*/
	reg aluz;
	always @(aluout_M or aluz)
		aluz = aluout_M == 16'h0000;
	
	// The ALU unit
	reg [(DBITS-1):0]  aluin1, aluin2, aluin2_A, aluout_M;
	wire [(DBITS-1):0] aluout;
	// Decided by control logic
	reg [3:0] alufunc, alufunc_A;
	
	always @(posedge clk) begin
		aluin2_A <= aluin2;
		alufunc_A <= alufunc;
	end
	
	ALU #(
		.BITS(DBITS),
		.CBITS(4),
		.CMD_ADD( ALU_ADD),
		.CMD_SUB( ALU_SUB),
		.CMD_LT(  ALU_LT),
		.CMD_LE(  ALU_LE),
		.CMD_AND( ALU_AND),
		.CMD_OR(  ALU_OR),
		.CMD_XOR( ALU_XOR),
		.CMD_NAND(ALU_NAND),
		.CMD_NOR( ALU_NOR),
		.CMD_NXOR(ALU_NXOR)
	) alu(.A(rregout1),.B(immsig_A?aluin2_A:rregout2),.CTL(alufunc_A),.OUT(aluout));

	always @(posedge clk)
		aluout_M <= aluout;

	always @(wrreg_M or wregval_M or aluout_M or opcode1_M or dmemout or pcplus_M) begin
		wregval_M = aluout_M;
		if(opcode1_M == OP1_LW)		// TODO: think of a brilliant way to remove the need for opcode1_M
			wregval_M = dmemout;
		else if(opcode1_M == OP1_JMP)
			wregval_M = pcplus_M;
	end


  // Used by control logic for BEQ and BNE (is ALU output zero?)
  //wire aluoutz=(aluout==16'b0);

  reg wrmem;
  reg [(DBITS-1):0] dmemaddr, dmemin;
  // Warning: The file you submit for Project 1 must not use negedge for anything
	always @(dmemaddr or aluout_M)
		dmemaddr = aluout_M;

	always @(dmemin or regout2_M)
		dmemin = regout2_M;
	
  reg [(DBITS-1):0] HexOut;
  SevenSeg ss3(.OUT(digit3),.IN(HexOut[15:12]));
  SevenSeg ss2(.OUT(digit2),.IN(HexOut[11:8]));
  SevenSeg ss1(.OUT(digit1),.IN(HexOut[7:4]));
  SevenSeg ss0(.OUT(digit0),.IN(HexOut[3:0]));
  /*
  	always @(posedge clk)
		HexOut=inst;
	*/
		
  
  reg [7:0] LedGOut;
  assign ledgreen=LedGOut;
  reg [9:0] LedROut;
  assign ledred=LedROut;
	always @(posedge clk) begin
		if(wrmem_M) begin
			// Insert code to store HexOut, LedROut, and LedGOut from dmemin when appropriate
			if(dmemaddr == 16'hFFF8)
				HexOut <= dmemin;
			else if(dmemaddr == 16'hFFFA)
				LedROut <= dmemin[9:0];
			else if(dmemaddr == 16'hFFFC)
				LedGOut <= dmemin[7:0];
		end
	end
	
	/*
	always @(posedge clk) begin
		//LedROut[2:0] = wregno_M;
		//LedROut[5:3] = rregno1_A;
		//LedROut[8:6] = rregno2_A;
		//LedROut = rregout2;
		//LedROut = aluin2_A;
		LedROut = aluout;
		//LedROut = aluout[8:0];
	end
	*/

	reg wrmem_A, wrmem_M;
	always @(posedge clk) begin
		wrmem_A <= wrmem;
		wrmem_M <= wrmem_A;
		if(flush) begin
			wrmem_A <= 1'b0;
			wrmem_M <= 1'b0;
		end
	end

  wire [(DBITS-1):0] MemVal;
  // Connect memory array to other signals
  wire MemEnable=(dmemaddr[(DBITS-1):13]==3'b0);
  MemArray #(.DBITS(DBITS),.ABITS(12),.MFILE("Sorter3.mif")) memArray(
    .ADDR1(dmemaddr[12:1]),.DOUT1(MemVal),
    .ADDR2(imemaddr[12:1]),.DOUT2(imemout),
    .DIN(dmemin),
    .WE(wrmem_M&&MemEnable),.CLK(clk));
	
  // Insert code to output MemVal, keys, or switches according to the dmemaddr
  wire [(DBITS-1):0] dmemout=MemEnable?MemVal:
		//(dmemaddr==16'hfff0)?{KEY[3],KEY[2],KEY[1],1'b1}:
		(dmemaddr==16'hfff0)?keys:
		(dmemaddr==16'hfff2)?switches:16'hDEAD;

	// This is the entire decoding logic. But it generates some values (aluin2, wregval, nextPC) in addition to control signals
	// You may want to have these values selected in the datapath, and have the control logic just create selection signals
	// E.g. for aluin2, you could have "assign aluin=regaluin2?regout2:dimm;" in the datapath, then set the "regaluin2" control signal here
	always @(opcode1 or opcode2 or rdst or rsrc1 or rsrc2 or pcplus or pctarg or rregout1 or rregout2 or aluout or 
	dmemout or dimm or  PC or opcode1_M or aluz or pcplus_M or flush or opcode1_A or regout1_M) begin
    {aluin2,  alufunc,wrmem, wregno,wrreg,nextPC,immsig,flush}=
    {{(DBITS){1'bX}},{4{1'bX}}, 1'b0, {3{1'bX}},1'b0 ,pcplus,1'b0,1'b0};
	case(opcode1)
	OP1_ALU:
		{alufunc,wregno,wrreg}=
		{opcode2,rdst,1'b1};
	OP1_ADDI:
		{aluin2,alufunc,wregno,wrreg,immsig} =
		{dimm,ALU_ADD,rsrc2,1'b1,1'b1};
	OP1_BEQ:
		{alufunc,nextPC}=
		{ALU_XOR,pctarg};
	OP1_BNE:
		{alufunc,nextPC}=
		{ALU_XOR,pctarg};
	OP1_LW:
		{aluin2,alufunc,wregno,wrreg,immsig} =
		{dimm,ALU_ADD,rsrc2,1'b1,1'b1};
	OP1_SW:
		{aluin2,alufunc,wrmem,immsig} =
		{dimm,ALU_ADD,1'b1,1'b1};
	OP1_JMP: begin
		{wregno,wrreg}=
		{rdst,1'b1};
	end
	default:
	  ;
	endcase
	// Branch Correction
	if(aluz) begin
		if( opcode1_M == OP1_BNE) begin
			nextPC = pcplus_M;
			flush = 1'b1;
		end
	end
	else begin
		if( opcode1_M == OP1_BEQ) begin
			nextPC = pcplus_M;
			flush = 1'b1;
		end
	end
	if(opcode1_M == OP1_JMP) begin
		flush = 1'b1;
		nextPC = regout1_M;
	end

  end

endmodule
