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
  wire signed [(BITS-1):0] A,B,Bn = ~B;
  reg signed [(BITS-1):0] tmpout, addsubout, cmpout, logout;
  reg signed [(BITS):0] x,y,sum;
  wire addsub = ~CTL[3]&~CTL[2], cmp = ~CTL[3]&CTL[2], sub = CTL[3] | CTL[2] | CTL[1] | CTL[0];
  reg cin;
  always @(A or B or Bn or CTL or sub or y or addsub or logout or cmpout or addsubout or sum or tmpout or cmp) begin
    x={A,1'b1}; 
    y={ B & {(BITS){~sub}} | Bn & {(BITS){sub}}  ,sub};
		/*
    if(CTL[0]|CTL[2]) begin
	    cin = 1'b1;
	    y={Bn,cin};
    end
		*/

    sum = (x+y);
    addsubout = sum[BITS:1];
    cmpout = {{(BITS-1){1'b0}},addsubout[(BITS-1)]};

    case(CTL)
      CMD_AND:  logout = A&B;
      CMD_OR:   logout = A|B;
      CMD_XOR:  logout = A^B;
      CMD_NAND: logout = ~(A&B);
      CMD_NOR:  logout = ~(A|B);
      CMD_NXOR: logout = ~(A^B);
      default:  logout = {BITS{1'bX}};
    endcase

    tmpout = (addsubout & {(BITS){addsub}}) |  (logout & {(BITS){CTL[3]}}) |  (cmpout & {(BITS){cmp}}); 

  end


  assign OUT=tmpout;
endmodule
