module RegFile(RADDR1,DOUT1,RADDR2,DOUT2,WADDR,DIN,WE,CLK);
  parameter DBITS; // Number of data bits
  parameter ABITS; // Number of address bits
  parameter WORDS = (1<<ABITS);
  parameter MFILE = "";
  (* ram_init_file = MFILE *)
  reg [(DBITS-1):0] mem[(WORDS-1):0];
  input  [(ABITS-1):0] RADDR1,RADDR2,WADDR;
  input  [(DBITS-1):0] DIN;
  output wire [(DBITS-1):0] DOUT1,DOUT2;
  input CLK,WE;
  always @(posedge CLK)
    if(WE)
      mem[WADDR]=DIN;
  assign DOUT1=mem[RADDR1];
  assign DOUT2=mem[RADDR2];
endmodule
