module Proj1(SW,KEY,LEDR,LEDG,HEX0,HEX1,HEX2,HEX3,CLOCK_50);
  input  [9:0] SW;
  input  [3:0] KEY;
  input  CLOCK_50;
  output [9:0] LEDR;
  output [7:0] LEDG;
  output [6:0] HEX0,HEX1,HEX2,HEX3;

  wire clk,lock;
  // TODO: Create a PLL using the MegaWizard in order for this to work
  Pll pll(.inclk0(CLOCK_50),.c0 (clk),.locked(lock));
  // Use this instead to step the processor using KEY[3]
/*
  wire clk=KEY[3];
  wire lock=1'b1;
*/
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
  MEM #(.DBITS(DBITS),.ABITS(12),.MFILE("Sorter1.mif")) memory(
    .ADDR(MAR[12:1]),
    .DIN(memin),
    .DOUT(MemVal),.WE(WrMem&&MemEnable),.CLK(clk));
  wire [(DBITS-1):0] memout=
	 MemEnable?MemVal:
	 // TODO: memout should get values of KEY (not !KEY) and SW when addresses of those devices are used
	 16'hDEAD;
  // Connect memory array output to bus (controlled by DrMem)
  assign thebus=DrMem?memout:BUSZ;
  
  // TODO: Create the IR (instruction register) and connect it to the bus
  // TODO: Also create opcode1, rsrc1, rsrc2, etc. signals from the IR (needed by control unit)
  
  // TODO: Create the registers unit and connect it to the bus
  
  // TODO: Create ALU unit and connect to the bus (using A and B registers for ALU input)

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

  parameter S_BITS=5;
  parameter [(S_BITS-1):0]
    S_ZERO  ={(S_BITS){1'b0}},
    S_ONE   ={{(S_BITS-1){1'b0}},1'b1},
    S_FETCH1=S_ZERO,				// 00000
    S_FETCH2=S_FETCH1+S_ONE,  // 00001
    // TODO: Add all the states you need for your state machine

  reg [(S_BITS-1):0] state=S_FETCH1,next_state;
  always @(state or opcode1 or rsrc1 or rsrc2 or rdst or opcode2 or ALUzero) begin
    ALUfunc=CMD_ADD;
    {LdPC,DrPC,IncPC,LdMAR,WrMem,DrMem,LdIR,DrOff,ShOff, LdA, LdB,DrALU,regno,DrReg,WrReg,next_state}=
    {1'b0,1'b0, 1'b0, 1'b0, 1'b0, 1'b0,1'b0, 1'b0, 1'b0,1'b0,1'b0, 1'b0, 3'b0, 1'b0, 1'b0,state+S_ONE};
    case(state)
    S_FETCH1: {DrPC,LdMAR}={1'b1,1'b1};
    S_FETCH2: {DrMem,LdIR,IncPC}={1'b1,1'b1,1'b1};
    S_FETCH3: begin
	             case(opcode1)
					 OP1_ALU:  begin
					             next_state=S_ALU1;
    // TODO: Write the rest of the state machine
	 endcase
  end
  always @(posedge clk)
	if(lock)
		state<=next_state;
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
