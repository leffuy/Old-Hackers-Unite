	module Proj1(SW,KEY,LEDR,LEDG,HEX0,HEX1,HEX2,HEX3,CLOCK_50);
  input  [9:0] SW;
  input  [3:0] KEY;
  input  CLOCK_50;
  output [9:0] LEDR;
  output [7:0] LEDG;
  output [6:0] HEX0,HEX1,HEX2,HEX3;

  //wire clk,lock;
  // TODO: Create a PLL using the MegaWizard in order for this to work
  //Pll pll(.inclk0(CLOCK_50),.c0 (clk),.locked(lock));
  // Use this instead to step the processor using KEY[3]
/*
  wire clk=KEY[3];
  wire lock=1'b1;
*/
  wire lock=1'b1;
assign clk = CLOCK_50;
  // Create the processor's bus
  parameter DBITS=16;
  tri [(DBITS-1):0] thebus;
  parameter BUSZ={DBITS{1'bZ}};
  
  // Create PC and connect it to the bus
  reg [(DBITS-1):0] PC=16'h200;
  reg LdPC, DrPC, IncPC;
  always @(posedge clk) begin
    if(LdPC)
      PC <= thebus;
    else if(IncPC)
      PC <= PC + 16'h2;
  end
  assign thebus=DrPC?PC:BUSZ;

  
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
 
  // Provide nice names for opcode2 values when opcode1==OP1_JMP
  parameter
    JMP_OP2_JRL = 4'b0000;
  
  // Create the memory unit and connect to the bus
  reg [(DBITS-1):0] MAR;  // MAR register
  reg LdMAR,WrMem,DrMem; // Control signals
  // Memory data input comes from the bus
  wire [(DBITS-1):0] memin=thebus; 
  // Connect MAR input to the bus
  always @(posedge clk)
    if(LdMAR)
      MAR <= thebus;
 
  // Real memory array used only if address is 0000 to 0FFF
  wire MemEnable=(MAR[(DBITS-1):13]==4'b0);
  // Note: You need to write an assembler to get Sorter1.mif from the Sorter1.a16 file
  // Note: Meanwhile. you can test your design using the Test1.mif file (see Test1,a16 for its source code)
  MEM #(.DBITS(DBITS),.ABITS(12),.MFILE("Test1.mif")) memory(
    .ADDR(MAR[12:1]),
    .DIN(memin),
    .DOUT(MemVal),.WE(WrMem&&MemEnable),.CLK(clk));
  wire [(DBITS-1):0] memout=
	 MemEnable?MemVal:
	 (MAR[15:0]==16'hff0)? KEY[3:0]:
	 (MAR[15:0]==16'hff2)? SW[9:0]:
	 16'hDEAD;
  // Connect memory array output to bus (controlled by DrMem)
  assign thebus=DrMem?memout:BUSZ;
  
  // TODO: Create the IR (instruction register) and connect it to the bus
  reg [(DBITS-1):0] IR;
  always @(posedge clk)
	if(LdIR)
		IR<=thebus;
  // TODO: Also create opcode1, rsrc1, rsrc2, etc. signals from the IR (needed by control unit)
  wire [2:0] opcode1 = IR[15:13],
		rsrc1 = IR[12:10],
		rsrc2 = IR[9:7],
		rdst = IR[6:4];
	wire [3:0] opcode2 = IR[3:0];
	reg [3:0] ALUfunc;
	wire [6:0] immediate;
	SXT #(.IBITS(7),.OBITS(16)) Off(IR[6:0],immediate);
	assign thebus=DrOff?immediate:16'hzzzz;
	
	assign LEDR[9:7] = opcode1;
	assign LEDR[6] = 1'b1;
	assign LEDR[5:2] = opcode2;
	
	reg LdA, LdB, DrALU, DrReg, WrReg, LdIR, DrOff, ShOff;
	reg [2:0] regno;
	//wire [7] imm = IR[6:0] // immediate?
  // TODO: Create the registers unit and connect it to the bus
  
  reg [ (DBITS-1):0] registers[8];
  
  wire [ (DBITS-1):0] register;
  assign register =	(regno==3'b000) ? registers[0]	// 0
							: (regno==3'b001) ? registers[1]	// 1
							: (regno==3'b010) ? registers[2] // 2
							: (regno==3'b011) ? registers[3]	// 3
							: (regno==3'b100) ? registers[4]	// 4
							: (regno==3'b101) ? registers[5]	// 5
							: (regno==3'b110) ? registers[6]	// 6
							: (regno==3'b111) ? registers[7]
							: 16'hbeef;	// impossible, or should be
  
  always @(posedge clk) begin
	if(WrReg==1'b1) begin
		case(regno)
			3'b000:	registers[0]<=thebus;
			3'b001:	registers[1]<=thebus;
			3'b010:	registers[2]<=thebus;
			3'b011:	registers[3]<=thebus;
			3'b100:	registers[4]<=thebus;
			3'b101:	registers[5]<=thebus;
			3'b110:	registers[6]<=thebus;
			3'b111:	registers[7]<=thebus;
		endcase
		end
	end
  
  assign thebus=DrReg?register:16'hzzzz;
  
  
  // TODO: Create ALU unit and connect to the bus (using A and B registers for ALU input)
  reg [ (DBITS-1):0] A, B;
	wire[ (DBITS-1):0 ] ALUval;
  always @(posedge clk)
	if(LdA==1'b1)
		A <= thebus;
  always @(posedge clk)
	if(LdB==1'b1)
		B <= thebus;
		
  assign thebus=DrALU?ALUval:16'hzzzz;
  ALU #(.BITS(16),.CBITS(4),
    .CMD_ADD(ALU_OP2_ADD),
	 .CMD_SUB(ALU_OP2_SUB),
	 .CMD_LT(ALU_OP2_LT),
	 .CMD_LE(ALU_OP2_LE),
	 .CMD_AND(ALU_OP2_AND),
	 .CMD_OR(ALU_OP2_OR),
	 .CMD_XOR(ALU_OP2_XOR),
	 .CMD_NAND(ALU_OP2_NAND),
	 .CMD_NOR(ALU_OP2_NOR),
	 .CMD_NXOR(ALU_OP2_NXOR)
  ) thealu (A,B,ALUfunc,ALUval);


  parameter S_BITS=5;
  parameter [(S_BITS-1):0]
		S_ZERO  ={(S_BITS){1'b0}},
		S_ONE   ={{(S_BITS-1){1'b0}},1'b1},
		S_FETCH1=S_ZERO,				// 00000
		S_FETCH2=S_FETCH1+S_ONE,  // 00001
		S_FETCH3=S_FETCH2+S_ONE,  // 00010
		S_ALU1	=S_FETCH3+S_ONE,	// 00011
		S_ALU_ADD1 = S_ALU1+S_ONE,	// 00100
		S_ALU_ADD2	= S_ALU_ADD1+S_ONE,	// 00101
		S_ALU_SUB1	= S_ALU_ADD2+S_ONE,	// 00111
		S_ALU_ADDI1	= S_ALU_SUB1+S_ONE, // 01000
		S_BEQ1 = S_ALU_ADDI1+S_ONE,
		S_BEQ2 = S_BEQ1+S_ONE,
		S_BEQ3 = S_BEQ2+S_ONE,
		S_BNE1 = S_BEQ3+S_ONE,
		S_LW1 = S_BNE1+S_ONE,
		S_LW2 = S_LW1+S_ONE,
		S_LW3 = S_LW2+S_ONE,
		S_LW4 = S_LW3+S_ONE,
		S_SW1 = S_LW4+S_ONE,
		S_SW2 = S_SW1+S_ONE,
		S_SW3 = S_SW2+S_ONE,
		S_SW4 = S_SW3+S_ONE,
		S_JMP1 = S_SW1+S_ONE,
		S_JMP2 = S_JMP1+S_ONE
	;
    // TODO: Add all the states you need for your state machine

	 reg ALUzero;
	 initial ALUzero <=  0;
  reg [(S_BITS-1):0] state=S_FETCH1,next_state;
  always @(state or opcode1 or rsrc1 or rsrc2 or rdst or opcode2 or ALUzero) begin
    ALUfunc=ALU_OP2_ADD;
    {LdPC,DrPC,IncPC,LdMAR,WrMem,DrMem,LdIR,DrOff,ShOff, LdA, LdB,DrALU,regno,DrReg,WrReg,next_state}=
    {1'b0,1'b0, 1'b0, 1'b0, 1'b0, 1'b0,1'b0, 1'b0, 1'b0,1'b0,1'b0, 1'b0, 3'b0, 1'b0, 1'b0,state+S_ONE};
    case(state)
    S_FETCH1: {DrPC,LdMAR}={1'b1,1'b1};
    S_FETCH2: {DrMem,LdIR,IncPC}={1'b1,1'b1,1'b1};
    S_FETCH3: begin
	            case(opcode1)
						OP1_ALU: next_state=S_ALU1;
						OP1_ADDI: next_state=S_ALU_ADDI1;
						OP1_BEQ : next_state=S_BEQ1;
						OP1_BNE : next_state=S_BNE1;
						OP1_LW  : next_state=S_LW1;
						OP1_SW  : next_state=S_SW1;
						OP1_JMP : next_state=S_JMP1;
					endcase
					end
	S_BEQ1:	begin
					regno=rsrc1;
					DrReg=1'b1;
					LdA=1'b1;
					next_state=S_BEQ2;
				end
	S_BEQ2:	begin
					regno=rsrc2;
					DrReg=1'b1;
					LdB=1'b1;
					next_state=S_BEQ3;
				end
	S_BEQ3:	begin
					ALUfunc=ALU_OP2_LT;
					DrALU=1'b1;
					next_state=S_BEQ3;
					if(thebus==16'h0001)
						next_state=S_FETCH1;
				end
	S_BNE1: next_state=S_FETCH1;
	S_LW1:	begin
					regno=rsrc1;
					DrReg=1'b1;
					LdA=1'b1;
					next_state=S_LW2;
				end
	S_LW2:	begin
					DrOff=1'b1;
					LdB=1'b1;
					next_state=S_LW3;
				end
	S_LW3:	begin
					LdMAR=1'b1;
					DrALU=1'b1;
					next_state=S_LW4;
				end
	S_LW4:	begin
					regno=rdst;
					WrReg=1'b1;
					DrMem=1'b1;
					next_state=S_FETCH1;
				end
	S_SW1: begin
					regno=rsrc1;
					DrReg=1'b1;
					LdA=1'b1;
					next_state=S_SW2;
				end
	S_SW2: begin
					DrOff=1'b1;
					LdB=1'b1;
					next_state=S_SW3;
				end
	S_SW3: begin
					DrALU=1'b1;
					LdMAR=1'b1;
					next_state=S_SW4;
				end
	S_SW4: begin
					WrMem=1'b1;
					regno=rsrc2;
					DrReg=1'b1;
					next_state=S_FETCH1;
				end
	S_JMP1: begin
					regno=rdst;
					WrReg=1'b1;
					next_state=S_JMP2;
				end
	S_JMP2: begin
					LdPC=1'b1;
					DrReg=1'b1;
					regno=rsrc1;
					next_state=S_FETCH1;
				end
   S_ALU1: begin
					regno=rsrc1;
					DrReg=1'b1;
					LdA=1'b1;
					case(opcode2)
						ALU_OP2_ADD: next_state=S_ALU_ADD1;
						ALU_OP2_SUB: begin
							next_state=S_ALU_SUB1;
							ALUfunc=ALU_OP2_SUB;
							end
						ALU_OP2_LT:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_LT;
							end
						ALU_OP2_LE:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_LE;
							end
						ALU_OP2_AND:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_AND;
							end
						ALU_OP2_OR:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_OR;
							end
						ALU_OP2_XOR:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_XOR;
							end
						ALU_OP2_NAND:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_NAND;
							end
						ALU_OP2_NOR:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_NOR;
							end
						ALU_OP2_NXOR:  begin
							next_state=S_ALU_ADD1;
							ALUfunc=ALU_OP2_NXOR;
							end
					endcase
				end
	S_ALU_SUB1: begin
						regno=rsrc2;
						DrReg=1'b1;
						LdB=1'b1;
						next_state=S_ALU_ADD2;
					end
	S_ALU_ADDI1: begin
						DrOff=1'b1;
						LdB=1'b1;
						next_state=S_ALU_ADD2;
					end
	S_ALU_ADD1:	begin
						regno=rsrc2;
						DrReg=1'b1;
						LdB=1'b1;
						next_state=S_ALU_ADD2;
					end
	S_ALU_ADD2:	begin
						regno=rdst;
						WrReg=1'b1;
						DrALU=1'b1;
						next_state=S_FETCH1;
					end
	 endcase
  end
  always @(posedge clk)
	if(lock)
		state<=next_state;
		
	SevenSeg h0(HEX0,thebus[3:0]);
	SevenSeg h1(HEX1,thebus[7:4]);
	SevenSeg h2(HEX2,thebus[11:8]);
	SevenSeg h3(HEX3,thebus[15:12]);
endmodule

module MEM(ADDR,DIN,DOUT,WE,CLK);
  parameter DBITS; // Number of data bits
  parameter ABITS; // Number of address bits
  parameter WORDS = (1<<ABITS);
  parameter MFILE = "";
  (* ram_init_file = MFILE *) 
  reg [(DBITS-1):0] mem[(WORDS-1):0];
  input [(ABITS-1):0]  ADDR;
  input [(DBITS-1):0]  DIN;
  output [(DBITS-1):0] DOUT;
  input CLK,WE;
  always @(posedge CLK) begin
    if(WE)
      mem[ADDR] <= DIN;
  end
  assign DOUT = mem[ADDR];
endmodule

module SXT(IN,OUT);
  parameter IBITS;
  parameter OBITS;
  input  [(IBITS-1):0] IN;
  output [(OBITS-1):0] OUT;
  assign OUT={{(OBITS-IBITS){IN[IBITS-1]}},IN};
endmodule

module ALU(A,B,CTL,OUT);
  parameter BITS;  // Number of data bits
  parameter CBITS; // Number of control bits
  parameter
	 // Naaes for different values of the control input
    CMD_ADD,
	 CMD_SUB,
	 CMD_LT,
	 CMD_LE,
	 CMD_AND,
	 CMD_OR,
	 CMD_XOR,
	 CMD_NAND,
	 CMD_NOR,
	 CMD_NXOR;
  input  [(CBITS-1):0] CTL;
  input  [(BITS-1):0] A,B;
  output [(BITS-1):0] OUT;
  wire signed [(BITS-1):0] A,B;
  reg signed [(BITS-1):0] tmpout;
  always @(A or B or CTL) begin
    case(CTL)
      CMD_ADD:  tmpout = A+B;
      CMD_SUB:  tmpout = A-B;
      CMD_LT:   tmpout = (A<B);
      CMD_LE:   tmpout = (A<=B);
      CMD_AND:  tmpout = A&B;
      CMD_OR:   tmpout = A|B;
      CMD_XOR:  tmpout = A^B;
      CMD_NAND: tmpout = ~(A&B);
      CMD_NOR:  tmpout = ~(A|B);
      CMD_NXOR: tmpout = ~(A^B);
      default:  tmpout = {BITS{1'bX}};
    endcase
  end
  assign OUT=tmpout;
endmodule
