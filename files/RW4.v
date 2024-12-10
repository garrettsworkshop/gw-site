module RW4(
	/* Clocks */
	input C14M,
	input C7M,
	input Q3,
	input PHI1,
	/* 6502 address/select */
	input RnW,
	input RnW80,
	input nEN80,
	input nC07X,
	input [7:0] RA,
	/* Apple II DRAM control */
	input nPCAS,
	input nCASEN,
	input nPRAS,
	/* 6502 data bus */
	input [7:0] MD,
	/* DRAM */
	output reg nRAS,
	output reg nCAS,
	output nOE,
	output reg nWE,
	output reg [10:0] A)

	/* State counter */
	reg [3:0] S;
	reg [6:0] PHI1r;
	always @(posedge C14M) PHI1r[6:0] <= { PHI1r[6:0], PHI1 });
	always @(posedge C14M) begin
		if (!PHI1r[6] && PHI1r[5:0] && PHI1) S <= 4'h1;
		else if (S!=4'hF && S!=4'h0) S <= S+4'h1;
	end

	/* RAMWorks bank register */
	reg [5:0] Bank;
	reg BankWR;
	always @(posedge C14M) begin
		if (S==4'h2) BankWR <= !nWE && !RA[3] && RA[0];
		else if (S==4'h5) BankWR <= BankWR && !nC07X;
	end
	always @(posedge C14M) if (S==4'h6 && BankWR) Bank[5:0] <= MD[5:0];

	/* Refresh counter */
	reg [2:0] RefC;
	wire RefCTC = RefC==3'h6;
	always @(posedge C14M) begin
		if (RefCTC) RefC <= 0;
		else RefC <= RefC+3'h1;
	end

	/* DRAM control */
	always @(posedge C14M) nRAS <= !(
		((S==4'h3 || S==4'h4) && !nEN80) ||
		((S==4'h6 || S==4'h7) && RefCTC) ||
		((S==4'hA || S==4'hB)));
	always @(posedge C14M) nWE <= !((S==4'h3 || S==4'h4) && !nEN80 && !nWE);
	always @(posedge C14M) nCAS <= !(
		S==4'h4 || S==4'h5 || S==4'h6 || S==4'h7 ||
		S==4'hB || S==4'hC || S==4'hD || S==4'hE || S==4'hF);

	/* DRAM OE */
	reg OEPHI1;
	reg OE;
	always @(posedge C14M) OEPHI1 <=
		S==4'h9 || S==4'hA || S==4'hB || 
		S==4'hC || S==4'hD || S==4'hE || S==4'hF;
	always @(posedge C14M) OE <=
		S==4'h3 || S==4'h4 || S==4'h5 || 
		S==4'h6 || S==4'h7 || S==4'h8 || S==4'h9;
	assign nOE = !(OE || (PHI1 && OEPHI1));

	/* DRAM address */
	always @(negedge C14M) begin
		if (((S==4'h2 || S==4'h4) && !nEN80) ||
			((S==4'h9 || S==4'hB))) A[7:0] <= RA[7:0];
	end
	always @(negedge C14M) begin
		if (S==4'h2 && !nEN80) A[10:8] <= Bank[5:3];
		else if (S==4'h4 && !nEN80) A[10:8] <= Bank[2:0];
		else if (S==4'h9 || S==4'hB) A[10:8] <= 3'b000;
	end

	/* LED */
	assign LED = nEN80;
endmodule
