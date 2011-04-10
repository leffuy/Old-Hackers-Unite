`define MEMFILE "Test4.mif"

	// This code belongs in the stage where memory is read/written	

	// Note: selmem is set by the decoding logic
	// It is 1 only for LW, and indicates that the value
	// writen to the register is the one that is read from memory
	// (or memory-mapped devices)
	wire [(DBITS-1):0] abus=dmemaddr_M;
	wire               we  =wrmem_M;
	wire [(DBITS-1):0] wbus=regval2_M;
	wire               re  =selmem_M;

	// This is the bus to which devices output the value for a LW
	// A device should only output to rbus if it contains the address,
	// otherwise it must assign "z" to rbus to let others use it
	tri  [(DBITS-1):0] rbus;

	// This is a trick to avoid multiplexers later:
	// restmp_M contains the register value from the ALU stage
	// We simply treat it as one of the possible sources for the
	// value on the rbus, driving the rbus only if this is not a LW
	assign rbus=(!selmem_M)?restmp_M:{DBITS{1'bz}};

	Memory #(.ABITS(DBITS),.RABITS(13),.SABITS(1),
				.WBITS(DBITS),.MFILE(`MEMFILE))
	memory(	.IADDR(PC),.IOUT(inst_F),
				.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
				.CLK(clk),.LOCK(lock),.INIT(init));

	Display #(.ABITS(DBITS),.DBITS(DBITS),.DADDR(16'hFFF8))
	display(	.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
				.CLK(clk),.LOCK(lock),.INIT(init),
				.HEX0(digit0),.HEX1(digit1),.HEX2(digit2),.HEX3(digit3));

	Leds #(.ABITS(DBITS),.DBITS(DBITS),.LBITS(10),.DADDR(16'hFFFA))
	ledsr(	.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
				.CLK(clk),.LOCK(lock),.INIT(init),
				.LED(ledred));
				
	Leds #(.ABITS(DBITS),.DBITS(DBITS),.LBITS(8),.DADDR(16'hFFFC))
	ledsg(	.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
				.CLK(clk),.LOCK(lock),.INIT(init),
				.LED(ledgreen));

	wire intr_keys;
	KeyDev #(.ABITS(DBITS),.DBITS(DBITS),.DADDR(16'hFFF0),.CADDR(16'hFFF4))
	keyDev(	.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
				.INTR(intr_keys),.CLK(clk),.LOCK(lock),.INIT(init),
				.KEY(keys));

	wire intr_sws;
	SwDev #(.ABITS(DBITS),.DBITS(DBITS),.DADDR(16'hFFF2),.CADDR(16'hFFF6),
				.DEBB(20),.DEBN(21'd1000000))
	swDev(	.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
				.INTR(intr_sws),.CLK(clk),.LOCK(lock),.INIT(init),
				.SW(switches));

	wire intr_timer;
	Timer #(.ABITS(DBITS),.DBITS(DBITS),.RBASE(16'hFFE0),
				.DIVN(10000),.DIVB(14))
	timer(.ABUS(abus),.RBUS(rbus),.RE(re),.WBUS(wbus),.WE(we),
			.INTR(intr_timer),.CLK(clk),.LOCK(lock),.INIT(init));

	// This is the final register result from the MEM stage
	// (this is what will be written to a register if wrreg is 1)
	wire [(DBITS-1):0] result_M=rbus;

	// Note that you will also need to use the intr_* signals to
	// interrupt the processor as appropriate, and to set the SII
	//	value when jumping to the interrupt handler