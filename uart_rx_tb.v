// Testbench uses a 10 MHz clock
// 10M >> 16 * 115200 (baud rate)
// 10M / 115200 = 87 clocks per bit 

// Our total number of bits in the frame is 11, meaning the total frame duration is 95.7 us
// To ensure the capture of the full frame, set in the simulation program you are using to run for at least 2 times the frame duration
// By our calculations, the actual measure baud rate is approximately ~114,631 bps, about 0.5% error
// In UART most systems tolerate up to 2% baud rate mismatch before errors occur

`timescale 1ns/1ps

`include "uart_rx.v"

module uart_rx_tb();
	
	// Parameters
	parameter tb_clksPerBit  = 87;
	parameter clockPeriod 	 = 100; // 100ns  
	parameter bitPeriod   	 = 8700;  // Bit period = 1 / 87 * 100ns - each UART bit takes 8700 ns
	
	// Signals
	reg tb_clk 	 = 0;
	reg tb_txBit = 1;
	wire tb_rxFinished;
	wire [7:0] tb_rxBits;
	wire tb_parityError;
	
	// Instantiation of uart_rx
	uart_rx #(.clksPerBit(tb_clksPerBit)) uut (
		.i_clkRx(tb_clk),
		.i_txBit(tb_txBit),
		.o_rxFinished(tb_rxFinished),
		.o_rxBits(tb_rxBits),
		.o_parityError(tb_parityError)
	);
	
	// Clock generation (100MHz)
	always
		#(clockPeriod / 2) tb_clk <= !tb_clk;
	
	// Task for simulating UART transmitter
	task transmit;
		input [7:0] dataByte;
		input parityBit;
		integer i;
		begin
			$display("Transmit task started at %0t", $time);
			
			// Start bit (0)
			tb_txBit = 1'b0;
			$display("Start bit at %0t", $time);
			#(bitPeriod);
			
			// Parity bit
			tb_txBit = parityBit;
			$display("Parity Bit: %b at time: %0t", tb_txBit, $time);
			#(bitPeriod);
			
			// Data bits 
			for (i = 0; i < 8; i = i + 1) begin
				tb_txBit = dataByte[i];
				$display("Bit %0d: %b at time: %0t", i, tb_txBit, $time);
				#(bitPeriod);
			end
			
			// Stop bit (1)
			tb_txBit = 1'b1;
			$display("Stop Bit at %0t", $time);
			#(bitPeriod);
			
			$display("Transmit Task Finished at %0t", $time);
		end
	endtask
	
	// Testbench stimulation
	initial 
		begin
			// Wait a few clock cycles before td_txBit = 0
			@(posedge tb_clk);
			@(posedge tb_clk); 
			
			// Test case 1: send valid UART frame (8-bit data = 0x5A)
			$display("Sending valid UART frame (0x5A)");
			transmit(8'h5A, 1'b0);
			
			// Test case 1 result
			if ((tb_rxFinished == 1) && (tb_rxBits == 8'h5A) && (tb_parityError == 0))
				$display("PASS: Recieved 0x%h, Parity Error = %b", tb_rxBits, tb_parityError);
			else
				$display("FAIL: Data reception failed");
			
			@(posedge tb_clk);
			@(posedge tb_clk); 
			
			// Test case 2: send UART frame with parity error (8-bit data = 0x5A)
			$display("Sending UART frame (0x5A) with parity error");
			transmit(8'h5A, 1'b1);

			//Test case 2 result
			if (tb_rxFinished && tb_parityError)
				$display("PASS: Parity error detected");
			else
				$display("FAIL: Parity error not detected"); 
				
			// End of test
			$display("Test finished");
		end

endmodule