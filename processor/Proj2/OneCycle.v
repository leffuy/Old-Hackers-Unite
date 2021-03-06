module OneCycle(SW,KEY,LEDR,LEDG,HEX0,HEX1,HEX2,HEX3,CLOCK_50); 
	input  [9:0] SW;
	input  [3:0] KEY;
	input  CLOCK_50;
	output [9:0] LEDR;
	output [7:0] LEDG;
	output [6:0] HEX0,HEX1,HEX2,HEX3;
	`define MEMFILE "Sorter3.mif"

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

	reg init = 1'b0;
	always @(posedge clk) if(lock) init<=1'b1;

	always @(posedge clk) if(lock) begin
		if(!init)
			PC <= 16'h200;
		else if(intreq)
			PC <= SIH;
		else
			PC <= nextPC;
	end

	wire [(DBITS-1):0] pcplus=PC+16'd2;
	reg [(DBITS-1):0] pcplus_A, pcplus_M;
	always @(posedge clk) begin
		pcplus_A <= pcplus;
		pcplus_M <= pcplus_A;
	end

	// These are connected to the memory module
	//wire [(DBITS-1):0] imemaddr=PC;
	wire [(DBITS-1):0] imemout;

	wire [(DBITS-1):0] inst=imemout;
	wire [2:0] opcode1=inst[15:13];

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
	// opcode2 for JMP opcode1
	parameter
		JMP_OP2_JRL  = 4'b0000,
		JMP_OP2_RETI = 4'b0001,
		JMP_OP2_RSR  = 4'b0010,
		JMP_OP2_WSR  = 4'b0011;
	// shorter names for the above
	parameter
		JMP_JRL  = JMP_OP2_JRL,
		JMP_RETI = JMP_OP2_RETI,
		JMP_RSR  = JMP_OP2_RSR,
		JMP_WSR  = JMP_OP2_WSR;

	// names for system register numbers
	parameter
		SREG_SCS  =  3'b000,
		SREG_SIH  =  3'b001,
		SREG_SRA  =  3'b010,
		SREG_SII  =  3'b011,
		SREG_RES1 =  3'b100,
		SREG_RES2 =  3'b101,
		SREG_SR0  =  3'b110,
		SREG_SR1  =  3'b111;
	 

	wire [2:0] rsrc1  =inst[12:10];
	wire [2:0] rsrc2  =inst[ 9: 7];
	wire [2:0] rdst   =inst[ 6: 4];

	wire [3:0] opcode2=inst[ 3: 0];
	parameter IMMBITS=7;
	wire [(IMMBITS-1):0] imm=inst[(IMMBITS-1): 0];
	wire [(DBITS-1):0]   dimm={{(DBITS-IMMBITS){imm[IMMBITS-1]}},imm};
	wire [(DBITS-1):0]   bimm={{(DBITS-IMMBITS-1){imm[IMMBITS-1]}},imm,1'b0};

	reg [(DBITS-1):0] sregout_M, wrsysval_D, wrsysval_A, wrsysval_M;
	// signals
	reg wrsysen_D, wrsysen_A, wrsysen_M;
	reg immsig, immsig_A, flush, flushsig,
		retisig, retisig_A, retisig_M,
		selsysreg_D, selsysreg_A,selsysreg_M,
		alusig_D, alusig_A, alusig_M,
		BEQsig_D, BNEsig_D,JMPsig_D,
		BEQsig_A, BNEsig_A,JMPsig_A,
		BEQsig_M, BNEsig_M,JMPsig_M,
		LWsig_D, LWsig_A, LWsig_M;
	always @(posedge clk) begin
		immsig_A <= immsig;

		retisig_A <= retisig;
		retisig_M <= retisig_A;

		BEQsig_A <= BEQsig_D;
		BNEsig_A <= BNEsig_D;
		JMPsig_A <= JMPsig_D;

		BEQsig_M <= BEQsig_A;
		BNEsig_M <= BNEsig_A;
		JMPsig_M <= JMPsig_A;

		alusig_A <= alusig_D;
		alusig_M <= alusig_A;

		LWsig_A <= LWsig_D;
		LWsig_M <= LWsig_A;

		selsysreg_A <= selsysreg_D;
		selsysreg_M <= selsysreg_A;

		wrsysen_A <= wrsysen_D;
		wrsysen_M <= wrsysen_A;

		if(flush) begin
			BEQsig_A <= 1'b0;
			BNEsig_A <= 1'b0;
			JMPsig_A <= 1'b0;

			BEQsig_M <= 1'b0;
			BNEsig_M <= 1'b0;
			JMPsig_M <= 1'b0;

			LWsig_A <= 1'b0;
			LWsig_M <= 1'b0;

			wrsysen_A <= 1'b0;
			wrsysen_M <= 1'b0;

			selsysreg_A <= 1'b0;
			selsysreg_M <= 1'b0;

			alusig_A <= 1'b0;
			alusig_M <= 1'b0;
		end
	end

	wire [(DBITS-1):0] pctarg= pcplus+bimm;

	// The rregno2 always comes from rsrc2 field in the instruction word
	wire [2:0] rregno2=rsrc2;
	// rregno1 selects between RA and rsrc1 based on if RETI or not
	reg [2:0] rregno1, rregno1_A, rregno2_A, rregno1_M;
	wire [(DBITS-1):0] regout1, regout2;
	reg [(DBITS-1):0] fregout1_D, fregout2_D, fregout1_A, fregout2_A, regout1_A, regout2_A, regout1_M, regout2_M, jmptarg; 
	// These three are optimized-out "reg" (control logic uses an always-block)
	// But wregno may come from rsrc2 or rdst fields (decided by control logic)
	reg [2:0] wregno, wregno_A, wregno_M, wregno_W;
	reg wrreg, wrreg_A, wrreg_M, wrreg_W;
	reg [(DBITS-1):0] wregval_M, wregval_W;
	RegFile #(.DBITS(DBITS),.ABITS(3),.MFILE("Regs.mif")) regFile(
		.RADDR1(rregno1),.DOUT1(regout1),
		.RADDR2(rregno2),.DOUT2(regout2),
		.WADDR(wregno_W),.DIN(wregval_W),
		.WE(wrreg_W),.CLK(clk));

	// System registers
	reg IE, OIE, CM = 1'b1, OM;
	reg [(DBITS-1):0] SIH, SRA, SII, SR0, SR1;

	always @(rregno1_M or IE or OIE or CM or OM or SIH or SRA or SII or SR0 or SR1 or iinst_M or sregout_M) begin
		sregout_M = 16'hFAFA;
		if(!iinst_M) begin
		case(rregno1_M)
			SREG_SCS: sregout_M={{(DBITS-4){1'b0}},OM,CM,OIE,IE};
			SREG_SIH: sregout_M=SIH;
			SREG_SRA: sregout_M=SRA;
			SREG_SII: sregout_M=SII;
			SREG_SR0: sregout_M=SR0;
			SREG_SR1: sregout_M=SR1;
			default: sregout_M = 16'hFAFA;
		endcase
		end
	end

	always @(posedge clk) begin
		if(!lock) // We don't want any unintended side effects, might be a faster way
			wrreg_A <= 0;
		else
			wrreg_A <= wrreg;
		wrreg_M <= wrreg_A;
		wrreg_W <= wrreg_M;

		wregno_A <= wregno;
		wregno_M <= wregno_A;
		wregno_W <= wregno_M;

		wregno_W <= wregno_M;

		wregval_W <= wregval_M;

		rregno1_A <= rregno1;
		rregno1_M <= rregno1_A;
		rregno2_A <= rregno2;

		regout1_A <= fregout1_D;
		regout2_A <= fregout2_D;

		regout1_M <= fregout1_A;
		regout2_M <= fregout2_A;


		if(flush) begin
			wrreg_A <= 1'b0;
			wrreg_M <= 1'b0;
		end
		if(iinst_M)
			wrreg_W <= 1'b0;
	end

	always @(rregno1 or rregno2 or fregout1_D or fregout2_D or regout1 or regout2 or wrreg_M or wregno_M or wregval_M 
		or wrreg_W or wregno_W or wregval_W) begin
		fregout1_D = regout1;
		fregout2_D = regout2;
		if(wrreg_W) begin
			if(rregno1 == wregno_W)
				fregout1_D = wregval_W;
			if(rregno2 == wregno_W)
				fregout2_D = wregval_W;
		end
		if(wrreg_M) begin
			if(rregno1 == wregno_M)
				fregout1_D = wregval_M;
			if(rregno2 == wregno_M)
				fregout2_D = wregval_M;
		end
	end
	always @(rregno1_A or rregno2_A or fregout1_A or fregout2_A or wrreg_M or wregno_M or wregval_M 
		or wrreg_W or wregno_W or wregval_W or regout1_A or regout2_A) begin
		
		fregout1_A = regout1_A;
		fregout2_A = regout2_A;
		if(wrreg_W) begin
			if(rregno1_A == wregno_W)
				fregout1_A = wregval_W;
			if(rregno2_A == wregno_W)
				fregout2_A = wregval_W;
		end
		if(wrreg_M) begin
			if(rregno1_A == wregno_M)
				fregout1_A = wregval_M;
			if(rregno2_A == wregno_M)
				fregout2_A = wregval_M;
		end
	end

	reg aluz;
	always @(aluout_M or aluz)
		aluz = aluout_M == 16'h0000;
	
	// The ALU unit
	reg [(DBITS-1):0]  aluin1, aluin2, aluin2_A, aluout_M;
	wire [(DBITS-1):0] aluout_A;
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
	) alu(.A(fregout1_A),.B(immsig_A?aluin2_A:fregout2_A),.CTL(alufunc_A),.OUT(aluout_A));

	always @(posedge clk)
		aluout_M <= aluout_A;

	always @(wrreg_M or wregval_M or aluout_M or JMPsig_M or LWsig_M or result_M or pcplus_M or selsysreg_M or alusig_M) begin
		wregval_M = (aluout_M & {(DBITS){alusig_M}}) | (result_M & {(DBITS){(LWsig_M | selsysreg_M)}}) | (pcplus_M & {(DBITS){JMPsig_M}});
		// Using the above for speed reasons. 
		/*
		wregval_M = aluout_M;
		if(LWsig_M || selsysreg_M)		
			wregval_M = result_M;
		else if(JMPsig_M)
			wregval_M = pcplus_M;
		*/
	end


  // Used by control logic for BEQ and BNE (is ALU output zero?)
  //wire aluoutz=(aluout==16'b0);

	reg wrmem, wrmem_A, wrmem_M;
	always @(posedge clk) begin
		wrmem_A <= wrmem;
		wrmem_M <= wrmem_A;
		if(flush) begin
			wrmem_A <= 1'b0;
			wrmem_M <= 1'b0;
		end
	end

	// Note: selmem is set by the decoding logic
	// It is 1 only for LW, and indicates that the value
	// writen to the register is the one that is read from memory
	// (or memory-mapped devices)
	wire [(DBITS-1):0] abus=aluout_M;
	wire               we  =wrmem_M;
	wire [(DBITS-1):0] wbus=regout2_M;
	wire               re  =LWsig_M;

	// This is the bus to which devices output the value for a LW
	// A device should only output to rbus if it contains the address,
	// otherwise it must assign "z" to rbus to let others use it
	tri  [(DBITS-1):0] rbus;

	// This is a trick to avoid multiplexers later:
	// restmp_M contains the register value from the ALU stage
	// We simply treat it as one of the possible sources for the
	// value on the rbus, driving the rbus only if this is not a LW
	assign rbus=(alusig_M)?aluout_M:
		(selsysreg_M)?sregout_M:
		{DBITS{1'bz}};
	//assign rbus=(selsysreg_M)?sregout_M:{DBITS{1'bz}};

	Memory #(.ABITS(DBITS),.RABITS(13),.SABITS(1),
		.WBITS(DBITS),.MFILE(`MEMFILE))
	memory(.IADDR(PC),.IOUT(imemout),
		.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.CLK(clk),.LOCK(lock),.INIT(!init));

	Display #(.ABITS(DBITS),.DBITS(DBITS),.DADDR(16'hFFF8))
	display(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.CLK(clk),.LOCK(lock),.INIT(!init),
		.HEX0(digit0),.HEX1(digit1),.HEX2(digit2),.HEX3(digit3));

	Leds #(.ABITS(DBITS),.DBITS(DBITS),.LBITS(10),.DADDR(16'hFFFA))
	ledsr(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.CLK(clk),.LOCK(lock),.INIT(!init),.LED(ledred));

	Leds #(.ABITS(DBITS),.DBITS(DBITS),.LBITS(8),.DADDR(16'hFFFC))
		ledsg(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.CLK(clk),.LOCK(lock),.INIT(!init),.LED(ledgreen));

	wire intr_keys;
	KeyDev #(.ABITS(DBITS),.DBITS(DBITS),.DADDR(16'hFFF0),.CADDR(16'hFFF4))
	keyDev(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.INTR(intr_keys),.CLK(clk),.LOCK(lock),.INIT(!init),.KEY(keys));

	wire intr_sws;
	SwDev #(.ABITS(DBITS),.DBITS(DBITS),.DADDR(16'hFFF2),.CADDR(16'hFFF6),
		.DEBB(20),.DEBN(21'd1000000))
	swDev(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.INTR(intr_sws),.CLK(clk),.LOCK(lock),.INIT(!init),
		.SW(switches));

	wire intr_timer;
	Timer #(.ABITS(DBITS),.DBITS(DBITS),.RBASE(16'hFFE0),
		.DIVN(10000),.DIVB(14))
	timer(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
		.INTR(intr_timer),.CLK(clk),.LOCK(lock),.INIT(!init));

	// This is the final register result from the MEM stage
	// (this is what will be written to a register if wrreg is 1)
	wire [(DBITS-1):0] result_M=rbus;

	// Note that you will also need to use the intr_* signals to
	// interrupt the processor as appropriate, and to set the SII
	//      value when jumping to the interrupt handler
	wire intreq=(init) && ( iinst_M ||
		(IE && (intr_timer||intr_keys||intr_sws)));
	wire intr = intr_keys | intr_sws | intr_timer;
	wire [3:0] intnum =
		iinst_M		? 4'h0:
		intr_timer	? 4'h1:
		intr_keys	? 4'h2:
		intr_sws	? 4'h3: 4'hF;
	wire iinst_M = ((selsysreg_M || wrsysen_M) && !CM) || iinst_M1;

	always @(posedge clk) begin
		if(wrsysen_M && !iinst_M) begin
			case(wregno_M)
				SREG_SCS: {OM,CM,OIE,IE}<=regout1_M[3:0];
				SREG_SIH: SIH<=regout1_M;
				SREG_SRA: SRA<=regout1_M;
				SREG_SII: SII<=regout1_M;
				SREG_SR0: SR0<=regout1_M;
				SREG_SR1: SR1<=regout1_M;
				default:;
			endcase
		end
		if((IE && intr) || iinst_M) begin
			OM <= CM;
			CM <= 1'b1;
			OIE <= IE;
			IE <= 1'b0;
			SRA <= (iinst_M)?(pcplus_M-16'd2):nextPC;
			SII <= intnum;
		end
		if(retisig) begin
			IE <= OIE;
			CM <= OM;
		end
	end

	reg iinst_D, iinst_A, iinst_M1;

	always @(posedge clk)  begin
		iinst_A <= iinst_D;
		iinst_M1 <= iinst_A;
		if(flush) begin
			iinst_A <= 1'b0;
			iinst_M1 <= 1'b0;
		end
	end

	// This is the entire decoding logic. But it generates some values (aluin2, wregval, nextPC) in addition to control signals
	// You may want to have these values selected in the datapath, and have the control logic just create selection signals
	// E.g. for aluin2, you could have "assign aluin=regaluin2?regout2:dimm;" in the datapath, then set the "regaluin2" control signal here
	always @(opcode1 or opcode2 or rdst or rsrc1 or rsrc2 or pcplus or pctarg or fregout1_D or fregout2_D or rregno1 or rsrc1 or
	dimm or  PC or aluz or pcplus_M or flush or regout1_M or BEQsig_D or BNEsig_D or selsysreg_D or wrsysen_D or IE or intr or alusig_D or
 	JMPsig_D or BEQsig_M or BNEsig_M or JMPsig_M or init or inst or retisig or SRA or retisig_M or iinst_D or iinst_M) begin
	{rregno1, aluin2,          alufunc,   wrmem, wregno,    wrreg, nextPC,immsig,flush,BEQsig_D,BNEsig_D,JMPsig_D,LWsig_D, selsysreg_D, wrsysen_D, alusig_D,
	    retisig, iinst_D}=
	{rsrc1,   {(DBITS){1'bX}}, {4{1'bX}}, 1'b0,  {3{1'bX}}, 1'b0,  pcplus,1'b0,  1'b0, 1'b0,    1'b0,    1'b0,    1'b0,    1'b0,        1'b0,      1'b0,
	    1'b0, 1'b0};
	if(init) begin
	case(opcode1)
	OP1_ALU:
		if(inst == 16'h0009);
		else begin
			{alusig_D,alufunc,wregno,wrreg}=
			{1'b1,opcode2,rdst,1'b1};
			case(opcode2)
				ALU_ADD:;
				ALU_SUB:;
				ALU_LT:;
				ALU_LE:;
				ALU_XOR:;
				ALU_OR:;
				ALU_AND:;
				ALU_NOR:;
				ALU_NAND:;
				ALU_NXOR:;
				default: begin
					alusig_D = 1'b0;
					wrreg = 1'b0;
					iinst_D = 1'b1;
				end
			endcase
		end
	OP1_ADDI:
		{alusig_D,aluin2,alufunc,wregno,wrreg,immsig} =
		{1'b1,dimm,ALU_ADD,rsrc2,1'b1,1'b1};
	OP1_BEQ:
		{alufunc,nextPC,BEQsig_D}=
		{ALU_XOR,pctarg,1'b1};
	OP1_BNE:
		{alufunc,nextPC,BNEsig_D}=
		{ALU_XOR,pctarg,1'b1};
	OP1_LW:
		{aluin2,alufunc,wregno,wrreg,immsig,LWsig_D} =
		{dimm,ALU_ADD,rsrc2,1'b1,1'b1,1'b1};
	OP1_SW:
		{aluin2,alufunc,wrmem,immsig} =
		{dimm,ALU_ADD,1'b1,1'b1};
	OP1_JMP: 
		case(opcode2)
			JMP_JRL:
				{wregno,wrreg,JMPsig_D}=
				{rdst,1'b1,1'b1};
			JMP_RETI:
				{retisig}=
				{1'b1};

			JMP_RSR:
				{selsysreg_D,wregno,wrreg}=
				{1'b1,rdst,1'b1};
			JMP_WSR:
				{wrsysen_D,wregno}=
				{1'b1,rdst};
			default: iinst_D = 1'b1;
		endcase
	default: iinst_D = 1'b1;
	endcase

	// Branch Correction
	if(aluz) begin
		if( BNEsig_M ) begin
			nextPC = pcplus_M;
			flush = 1'b1;
		end
	end
	else begin
		if( BEQsig_M ) begin
			nextPC = pcplus_M;
			flush = 1'b1;
		end
	end
	if( JMPsig_M ) begin
		nextPC = regout1_M;
		flush = 1'b1;
	end

	if( retisig_M ) begin
		nextPC = SRA;
		flush = 1'b1;
	end
	// Interrupts
	if((IE && intr) || iinst_M) begin
		flush = 1'b1;
	end
	end
  end

endmodule
