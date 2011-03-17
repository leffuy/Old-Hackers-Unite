module TableArray(ADDR1,DOUT1,ADDR2,DIN,WE,CLK);
  parameter DBITS; // Number of data bits
  parameter ABITS; // Number of address bits
  parameter WORDS = (1<<ABITS);
  parameter MFILE = "";
  input  [(ABITS-1):0] ADDR1, ADDR2;
  input  [(DBITS-1):0] DIN;
  output reg [(DBITS-1):0] DOUT1;
  input CLK,WE;
  (* ram_init_file = MFILE *) (* ramstyle="no_rw_check" *)
  reg [(DBITS-1):0] mem[(WORDS-1):0];
  always @(posedge CLK)
    if(WE)
      mem[ADDR2] <= DIN;
  always @(ADDR1)
	DOUT1=mem[ADDR1];
endmodule
