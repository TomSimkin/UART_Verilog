`timescale 1ns/1ps

`include "uart_rx_fpga.v"

module uart_rx_fpga_tb;

    // Parameters
    parameter tb_clksPerBit  = 234;
    parameter clockPeriod    = 27; // 10 MHz
    parameter bitPeriod      = tb_clksPerBit * clockPeriod;

    // DUT I/O
    reg tb_clk = 0;
	reg tb_reset = 1;
    reg tb_txBit = 1;
    wire tb_rxFinished;
    wire [7:0] tb_rxBits;
    wire tb_parityError;

    // Instantiate the DUT
    uart_rx_fpga #(.clksPerBit(tb_clksPerBit)) uut (
        .i_clkRx(tb_clk),
		.i_reset(tb_reset),
        .i_txBit(tb_txBit),
        .o_rxFinished(tb_rxFinished),
        .o_rxBits(tb_rxBits),
        .o_parityError(tb_parityError)
    );

    // Clock generation
    always #(clockPeriod / 2) tb_clk = ~tb_clk;

    // Task to send a full UART frame
    task send_uart_frame;
        input [7:0] data;
        input parity;
        integer i;
        begin
            // Start bit
            tb_txBit = 1'b0; 
			#(bitPeriod);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                tb_txBit = data[i];
                #(bitPeriod);
            end

            // Parity bit
            tb_txBit = parity; 
			#(bitPeriod);

            // Stop bit
            tb_txBit = 1'b1; 
			#(bitPeriod);
			
			$display("Transmit Task Finished at %0t", $time);
        end
    endtask

    initial begin
        // Initialize
        $display("UART RX testbench started");
		
		tb_reset = 1;
		repeat (3) @(posedge tb_clk);
		tb_reset = 0;
        // Wait for stable clock
        repeat (2) @(posedge tb_clk);
		
        // ---------------------------
        // Test 1: send 0x5A with correct parity
        // ---------------------------
        $display("[TEST 1] Sending 0x5A with correct parity");
        send_uart_frame(8'h5A, ^8'h5A);
		
		// Wait until signal is defined
		wait(tb_rxFinished == 1);
		@(posedge tb_clk) // Let outputs settle
		
        if (tb_rxBits == 8'h5A && tb_parityError == 0)
            $display("[PASS] RX received 0x%h, parity OK", tb_rxBits);
        else
            $display("[FAIL] RX = 0x%h, parityError = %b", tb_rxBits, tb_parityError);
			
        // ---------------------------
        // Test 2: send 0x5A with wrong parity
        // ---------------------------
		
		wait(tb_rxFinished == 0);
		repeat (2) @(posedge tb_clk);
		
        $display("[TEST 2] Sending 0x5A with wrong parity");
        send_uart_frame(8'h5A, ~(^8'h5A));
		
		wait(tb_rxFinished == 1);
        if (tb_parityError)
            $display("[PASS] Parity error correctly detected");
        else
            $display("[FAIL] Parity error NOT detected");

        $display("Testbench completed at %0t", $time);
    end

endmodule
