`timescale 1ns/1ps

`include "uart_tx.v"

module uart_tx_tb();

	// Parameters
	parameter tb_clksPerBit  = 87;
	parameter clockPeriod 	 = 100; // 100ns  
	parameter bitPeriod   	 = 8700;  // Bit period = 1 / 87 * 100ns - each UART bit takes 8700 ns
	
	// Signals
	reg tb_clk = 1'b0;
	reg tb_enableTx = 1'b0;
	reg [7:0] tb_bitsTx = 0;
	wire tb_doneTx;
	wire tb_dataTx;

	
	// Instantiation of uart_tx
	uart_tx #(.clksPerBit(tb_clksPerBit)) uut (
		.i_clkTx(tb_clk),
		.i_enableTx(tb_enableTx),
		.i_bitsTx(tb_bitsTx),
		.o_dataTx(tb_dataTx),
		.o_doneTx(tb_doneTx)
	);
	
	// Clock generation (100MHz)
	always
		#(clockPeriod / 2) tb_clk <= !tb_clk;
	
	// Testbench stimulation
	initial 
		begin
			// Wait a few clock cycles 
			@(posedge tb_clk);
			@(posedge tb_clk); 
			
			// Test case 1: send 8-bit data = 0x5A (parity bit = 0)
			tb_enableTx = 1'b1;
			$display("Injecting 0x5A to Tx");
			tb_bitsTx = 8'h5A;
			@(posedge tb_clk); 
			tb_enableTx = 1'b0;
			@(posedge tb_doneTx)
			$display("Transmission 1 finished");
			
			// Test case 2: send 8-bit data = 0x5B (parity bit = 1)
			tb_enableTx = 1'b1;
			$display("Injecting 0x5B to Tx");
			tb_bitsTx = 8'h5B;
			@(posedge tb_clk); 
			tb_enableTx = 1'b0;
			@(posedge tb_doneTx)
			$display("Transmission 2 finished");
			
		end
		
endmodule		