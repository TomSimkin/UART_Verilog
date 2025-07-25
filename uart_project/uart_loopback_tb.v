`timescale 1ns/1ps // Every #1 delay is 1ns, simulator precision is 1ps

`include "uart_rx.v"
`include "uart_tx.v"

module uart_loopback_tb;

// Parameters
localparam integer clk_frequency   		= 27_000_000;       				// Clock frequency (27 MHz)
localparam integer baud_rate  			= 115_200;							// Serial baud rate
localparam integer cycles_per_bit 		= clk_frequency / baud_rate;		// ≈ 234 clock cycles
localparam real    clk_period 			= 1_000_000_000.0 / clk_frequency;  // ≈ 37.037 ns system clock period, 234 clock cycles make up 1 UART bit

// General signals
reg         clk 			= 0; 	// Clock input
reg         rst_n 			= 0; 	// Asynchronous reset input, low active

// Rx signals
reg         i_byte_accept 	= 0; 	// Rx ready to receive data
wire        o_done; 				// Rx finished process
wire [7:0]  o_data_byte;			// Received byte of data 
wire        parity_error; 			// Flag for correct/incorrect parity
wire        framing_error;			// Flag for correct/incorrect stop bit 

// Tx signals
reg [7:0] 	data_send		= 0;	// Data to send
reg 		tx_valid		= 0;	// Tx ready to send data
wire 		ready_tx;				// Tx ready to work on new byte 
wire 		o_tx;					// Serial data output

// Uart_rx instantiation 
uart_rx 
#(
	.clk_frequency(clk_frequency / 1_000_000), // 27 MHz -> 27 in uart_rx
	.baud_rate(baud_rate)
)
DUT_RX
(
	.i_clk         (clk),
    .i_rst_n       (rst_n),
    .i_byte_accept (i_byte_accept),
    .i_data_bit    (o_tx),
    .o_done        (o_done),
    .o_data_byte   (o_data_byte),
    .parity_error  (parity_error),
    .framing_error (framing_error)
);

// Uart_tx instantiation 	
uart_tx
#(
	.clk_frequency(clk_frequency / 1_000_000), // 27 MHz -> 27 in uart_rx
	.baud_rate(baud_rate)
)
DUT_TX
(
    .i_clk    	 (clk),
    .i_rst_n   	 (rst_n),
    .data_send 	 (data_send),
    .tx_valid  	 (tx_valid),
    .ready_tx  	 (ready_tx),
    .o_tx      	 (o_tx)
);

// Clock pulse  
initial 
begin
	clk = 0;
	forever #(clk_period / 2) clk = ~clk;
end

// Reset pulse
initial 
begin
	rst_n = 0;
	repeat (10) @(posedge clk);
	rst_n = 1;
end

// Send a byte when ready_tx is asserted
task send_byte;
	input [7:0] data;
	integer 	i;
	begin
		// Wait for DUT to be ready
		wait (ready_tx == 1'b1);
		@(posedge clk);
		
		// Give data_send the data byte for 1 cc
		data_send = data;
		tx_valid = 1'b1;
		@(posedge clk);
		tx_valid = 1'b0;
	end
endtask

// One‐cycle–pulse acknowledge
task ack_frame;
	begin
    #1;                   	// Tiny delta so o_done has settled
    i_byte_accept = 1'b1;   // Blocking assign
    @(posedge clk);		  	// Let the DUT sample it
    i_byte_accept = 1'b0;	// Back to zero
	end
endtask

integer errors; 		  // Count number of errors test sequence
reg [7:0] tests [0:2];
integer i;

initial
begin
	$display("Sample patterns tests:");
	// Few sample patterns
	tests[0] = 8'hAA;
	tests[1] = 8'h55;
	tests[2] = 8'hA5;
	
	// Reset error counter
	errors = 0;
	
	// Wait for reset release
	@(posedge rst_n);
	
	// Send tests
	for (i = 0; i < 3; i = i + 1)
	begin
		send_byte(tests[i]);
	
		// Wait for Rx to indicate done
		wait (o_done);
	
		// Verify tests
		if (o_data_byte != tests[i] || parity_error || framing_error)
		begin
			$display("FAIL test[%0d]: sent=%02h, got=%02h, p_err=%b, f_err=%b",
							i, tests[i], o_data_byte, parity_error, framing_error);
			errors = errors + 1;
		end
		else
			$display("PASS test[%0d] = %02h", i, tests[i]);
		
		// Acknowledge and clear o_done
		ack_frame();
		wait (!o_done);
		
		// Add gap between tests
		repeat(cycles_per_bit) @(posedge clk);
	end
	
	// Back-to-back two frames (no extra idle)
	$display("Back-to-back Test: 0x3C then 0xC3");
    send_byte(8'h3C);

    wait(o_done);
    if (o_data_byte !== 8'h3C) begin
      $display("FAIL B2B[0]: expected 3C got %02h", o_data_byte);
      errors = errors + 1;
    end else
      $display("PASS B2B[0]");
	  
	ack_frame();
	wait (!o_done);
	
	// Immediately queue the next byte 
	send_byte(8'hC3);
	wait(o_done);
    if (o_data_byte !== 8'hC3) begin
      $display("FAIL B2B[1]: expected C3 got %02h", o_data_byte);
      errors = errors + 1;
    end else
      $display("PASS B2B[1]");
	
	ack_frame();
	wait (!o_done);
	
	$display("LOOPBACK COMPLETE: %0d error(s)", errors);
end

endmodule