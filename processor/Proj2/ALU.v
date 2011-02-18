module ALU(A,B,CTL,OUT);
  parameter BITS;  // Number of data bits
  parameter CBITS; // Number of control bits
  parameter
	 // Names for different values of the control input
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
