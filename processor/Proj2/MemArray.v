module MemArray(ADDR1,DOUT1,ADDR2,DOUT2,DIN,WE,CLK);
  parameter DBITS; // Number of data bits
  parameter ABITS; // Number of address bits
  parameter WORDS = (1<<ABITS);
  parameter MFILE = "";
  input  [(ABITS-1):0] ADDR1,ADDR2;
  input  [(DBITS-1):0] DIN;
  output reg [(DBITS-1):0] DOUT1,DOUT2;
  input CLK,WE;
  (* ram_init_file = MFILE *) (* ramstyle="no_rw_check" *)
  reg [(DBITS-1):0] mem[(WORDS-1):0];
  always @(posedge CLK)
    if(WE)
      mem[ADDR1] <= DIN;
  always @(ADDR1)
	DOUT1=mem[ADDR1];
  always @(ADDR2)
	DOUT2=mem[ADDR2];
endmodule
