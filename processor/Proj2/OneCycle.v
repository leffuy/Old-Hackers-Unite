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
	//wire clk,lock;
	//OneCycPll oneCycPll(.inclk0(CLOCK_50),.c0(clk),.locked(lock));
	wire clk = KEY[0];
	//wire clk = CLOCK_50;
	wire lock = 1'b1;
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
	reg [(DBITS-1):0] st2pcplus, bpcplus;
	always @(posedge clk) begin
		st2pcplus <= pcplus;
		bpcplus <= st2pcplus;
	end

	// These are connected to the memory module
	wire [(DBITS-1):0] imemaddr=PC;
	wire [(DBITS-1):0] imemout;

	wire [(DBITS-1):0] inst=imemout;
	wire [2:0] opcode1=inst[15:13];
	reg [2:0] st2opcode1, bopcode1;

	always @(posedge clk) begin
		st2opcode1 <= opcode1;
		bopcode1 <= st2opcode1;
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
	reg immsig,st2immsig;
	always @(posedge clk)
		st2immsig <= immsig;

	wire [(DBITS-1):0] pctarg= pcplus+bimm;

	// The rregno1 and rregno2 always come from rsrc1 and rsrc2 field in the instruction word
	wire [2:0] rregno1=rsrc1, rregno2=rsrc2;
	reg [2:0] st2rregno1, st2rregno2;
	wire [(DBITS-1):0] regout1, regout2;
	reg [(DBITS-1):0] rregout1, rregout2, st2regout1, st2regout2, bregout2, jmptarg, brnchcmp;
	// These three are optimized-out "reg" (control logic uses an always-block)
	// But wregno may come from rsrc2 or rdst fields (decided by control logic)
	reg [2:0] wregno, st2wregno, bwregno;
	reg wrreg, st2wrreg, bwrreg;
	reg [(DBITS-1):0] bwregval;
	RegFile #(.DBITS(DBITS),.ABITS(3),.MFILE("Regs.mif")) regFile(
		.RADDR1(rregno1),.DOUT1(regout1),
		.RADDR2(rregno2),.DOUT2(regout2),
		.WADDR(bwregno),.DIN(bwregval),
		.WE(bwrreg),.CLK(clk));
	
	always @(posedge clk) begin
		st2wrreg <= wrreg;
		st2wregno <= wregno;
		bwregno <= st2wregno;
		bwrreg <= st2wrreg;

		st2rregno1 <= rregno1;
		st2rregno2 <= rregno2;
		st2regout1 <= regout1;
		st2regout2 <= regout2;

		bregout2 <= rregout2;
	end
	
	always @(st2rregno1 or st2rregno2 or rregout1 or rregout2 or regout1 or regout2 or bwrreg or bwregno or bwregval or st2regout1 or st2regout2) begin
		rregout1 = st2regout1;
		rregout2 = st2regout2;
		if(bwrreg) begin
			if(st2rregno1 == bwregno)
				rregout1 = bwregval;
			if(st2rregno2 == bwregno)
				rregout2 = bwregval;
		end
	end
	
	always @(rregno1 or regout1 or regout2 or rregno2 or st2wrreg or st2wregno or st2opcode1 or aluout or jmptarg or brnchcmp or bwrreg or bwregno or bwregval) begin
		jmptarg = regout1;
		if(bwrreg) begin
			if(rregno1 == bwregno)
				jmptarg = bwregval;
		end
		if(st2wrreg && (st2opcode1 != OP1_LW)) begin
			if(rregno1 == st2wregno)
				jmptarg = aluout;
		end
	end

	wire aluz = aluout == 16'h000;
	
	// The ALU unit
	reg [(DBITS-1):0]  aluin1, aluin2, st2aluin2, baluout;
	wire [(DBITS-1):0] aluout;
	// Decided by control logic
   reg [3:0] alufunc, st2alufunc;
	
	always @(posedge clk) begin
		st2aluin2 <= aluin2;
		st2alufunc <= alufunc;
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
	) alu(.A(rregout1),.B(st2immsig?st2aluin2:rregout2),.CTL(st2alufunc),.OUT(aluout));

	always @(posedge clk)
		baluout <= aluout;
	
	always @(bwrreg or bwregval or baluout or bopcode1 or dmemout or bpcplus) begin
		bwregval = baluout;
		if(bopcode1 == OP1_LW)		// TODO: think of a brilliant way to remove the need for bopcode1
			bwregval = dmemout;
		else if(bopcode1 == OP1_JMP)
			bwregval = bpcplus;
	end


  // Used by control logic for BEQ and BNE (is ALU output zero?)
  //wire aluoutz=(aluout==16'b0);

  reg wrmem;
  reg [(DBITS-1):0] dmemaddr, dmemin;
  // Warning: The file you submit for Project 1 must not use negedge for anything
	always @(dmemaddr or baluout)
		dmemaddr = baluout;

	always @(dmemin or bregout2)
		dmemin = bregout2;
	
  reg [(DBITS-1):0] HexOut;
  SevenSeg ss3(.OUT(digit3),.IN(HexOut[15:12]));
  SevenSeg ss2(.OUT(digit2),.IN(HexOut[11:8]));
  SevenSeg ss1(.OUT(digit1),.IN(HexOut[7:4]));
  SevenSeg ss0(.OUT(digit0),.IN(HexOut[3:0]));
  	always @(posedge clk)
		HexOut=inst;
		
  
  reg [7:0] LedGOut;
  assign ledgreen=LedGOut;
  reg [9:0] LedROut;
  assign ledred=LedROut;
	always @(posedge clk) begin
		if(bwrmem) begin
			// Insert code to store HexOut, LedROut, and LedGOut from dmemin when appropriate
			/*if(dmemaddr[3:0] == 4'h8)
				HexOut <= dmemin;
			else if(dmemaddr[3:0] == 4'ha)
				LedROut <= dmemin[9:0];
			else*/ if(dmemaddr[3:0] == 4'hc)
				LedGOut <= dmemin[7:0];
		end
	end

	always @(posedge clk) begin
		//LedROut[2:0] = bwregno;
		//LedROut[5:3] = st2rregno1;
		//LedROut[8:6] = st2rregno2;
	//	LedROut = rregout1;
		LedROut = aluout;
		//LedROut = aluout[8:0];
	end

	reg st2wrmem, bwrmem;
	always @(posedge clk) begin
		st2wrmem <= wrmem;
		bwrmem <= st2wrmem;
	end

  wire [(DBITS-1):0] MemVal;
  // Connect memory array to other signals
  wire MemEnable=(dmemaddr[(DBITS-1):13]==3'b0);
  MemArray #(.DBITS(DBITS),.ABITS(12),.MFILE("ALUtest.mif")) memArray(
    .ADDR1(dmemaddr[12:1]),.DOUT1(MemVal),
    .ADDR2(imemaddr[12:1]),.DOUT2(imemout),
    .DIN(dmemin),
    .WE(bwrmem&&MemEnable),.CLK(clk));
	
  // Insert code to output MemVal, keys, or switches according to the dmemaddr
  wire [(DBITS-1):0] dmemout=MemEnable?MemVal:
		(dmemaddr==16'hfff0)?{KEY[3],KEY[2],KEY[1],1'b1}:
		//(dmemaddr==16'hfff0)?keys:
		(dmemaddr==16'hfff2)?switches:16'hDEAD;

	// This is the entire decoding logic. But it generates some values (aluin2, wregval, nextPC) in addition to control signals
	// You may want to have these values selected in the datapath, and have the control logic just create selection signals
	// E.g. for aluin2, you could have "assign aluin=regaluin2?regout2:dimm;" in the datapath, then set the "regaluin2" control signal here
	always @(opcode1 or opcode2 or rdst or rsrc1 or rsrc2 or pcplus or pctarg or rregout1 or rregout2 or aluout or 
	dmemout or dimm or  jmptarg or PC or st2opcode1 or aluz or st2pcplus) begin
    {aluin2,  alufunc,wrmem, wregno,wrreg,nextPC,immsig}=
    {{(DBITS){1'bX}},{4{1'bX}}, 1'b0, {3{1'bX}},1'b0 ,pcplus,1'b0};
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
		if(st2opcode1 == OP1_LW ) begin
			nextPC=PC;
		end
		else begin
			{wregno,wrreg,nextPC}=
			{rdst,1'b1,jmptarg};
		end
	end
	default:
	  ;
	endcase
	// Branch Correction
	if(aluz) begin
		if( st2opcode1 == OP1_BNE) begin
			nextPC = st2pcplus;
			wrreg = 1'b0;
			wrmem = 1'b0;
		end
	end
	else begin
		if( st2opcode1 == OP1_BEQ) begin
			nextPC = st2pcplus;
			wrreg = 1'b0;
			wrmem = 1'b0;
		end
	end

  end

endmodule
