`timescale 1ns/1ps

`include "uart_rx.v"
`include "uart_tx.v"

module uart_tb();
	
	// Parameters
	parameter tb_clksPerBit  = 87;
	parameter clockPeriod 	 = 100; // 100ns  
	parameter bitPeriod   	 = 8700;  // Bit period = 1 / 87 * 100ns - each UART bit takes 8700 ns
	
	// Global signals
	reg tb_clk 	 = 0;
	wire tb_dataTx;
	
	// Tx signals
	reg tb_enableTx = 0;
	reg [7:0] tb_bitsTx;
	
	// Rx signals
	wire tb_rxFinished;
	wire [7:0] tb_rxBits;
	wire tb_parityError;
	
	// Instantiation of uart_tx
	uart_tx #(.clksPerBit(tb_clksPerBit)) uut_tx (
		.i_clkTx(tb_clk),
		.i_enableTx(tb_enableTx),
		.i_bitsTx(tb_bitsTx),
		.o_dataTx(tb_dataTx),
		.o_doneTx()
	);
	
	// Instantiation of uart_rx
	uart_rx #(.clksPerBit(tb_clksPerBit)) uut_rx (
		.i_clkRx(tb_clk),
		.i_txBit(tb_dataTx),
		.o_rxFinished(tb_rxFinished),
		.o_rxBits(tb_rxBits),
		.o_parityError(tb_parityError)
	);
	
	// Clock generation (100MHz)
	always
		#(clockPeriod / 2) tb_clk <= !tb_clk;
		
	// Testbench stimulation
	initial 
		begin
			@(posedge tb_clk);
			@(posedge tb_clk); 
			
			// Test case 1: inject to Tx (8-bit data = 0x5A)
			tb_enableTx = 1'b1;
			$display("Injecting 0x5A to Tx");
			tb_bitsTx = 8'h5A;
			@(posedge tb_clk); 
			tb_enableTx = 1'b0;
			@(posedge tb_rxFinished)
			
			// Test case 1 result
			if ((tb_rxFinished == 1) && (tb_rxBits == 8'h5A) && (tb_parityError == 0))
				$display("PASS: Recieved 0x%h, Parity Error = %b", tb_rxBits, tb_parityError);
			else
				$display("FAIL: Data reception failed");
				
			// End of test
			$display("Test finished");
		end

endmodule