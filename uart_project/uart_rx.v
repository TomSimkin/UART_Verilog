module uart_rx 
#(
	parameter integer clk_frequency = 27, 	 // Clock frequency (27 MHz)
	parameter integer baud_rate 	= 115200 // Serial baud rate
)
(
	input 				i_clk, 			// Clock input
	input 				i_rst_n,	 	// Asynchronous reset input, low active
	input 				i_byte_accept, 	// Rx ready to receive data
	input 				i_data_bit, 	// Serial data input
	output reg 			o_done, 		// Rx finished process 
	output reg [7:0] 	o_data_byte, 	// Received byte of data 
	output reg 			parity_error,	// Flag for correct/incorrect parity
	output reg 			framing_error	// Flag for correct/incorrect stop bit 
);

localparam integer clk_cycle = (clk_frequency * 1000000) / baud_rate; // Number of FPGA clock cycles per UART bit period 

// State machine codes
localparam s_idle 				= 3'b000; // Idle
localparam s_start				= 3'b001; // Start bit
localparam s_data_byte 			= 3'b010; // 8 Data bits
localparam s_parity_check 		= 3'b011; // Check parity
localparam s_stop 				= 3'b100; // Stop bit
localparam s_hold 				= 3'b101; // Hold state for avoiding metastability


// Register decleration
reg [2:0] current_state, next_state; 	// States
reg		  rx_sync1, rx_sync2;	    	// FF's (delays) to avoid metastability
reg [7:0] clock_counter;		        // Clock cycle counter 
reg [7:0] temp_data;					// Temporary storage of received data
reg [2:0] bit_index;				    // Data bit location

// Synchronizer (UART idle = HIGH)
always @(posedge i_clk or negedge i_rst_n) 
begin
	if (i_rst_n == 1'b0)
	begin
		rx_sync1 <= 1'b1;
		rx_sync2 <= 1'b1;
	end
	else
	begin
		rx_sync1 <= i_data_bit;
		rx_sync2 <= rx_sync1;
	end
end

wire synced_data_bit = rx_sync2;

// FSM next-state - combinational
always @(*)
begin
	// Default : hold current state (avoid latch)
	next_state = current_state; 
	case (current_state)
		// IDLE: wait for line to go low (start bit = '0') 
		s_idle: 
			if (synced_data_bit == 1'b0) 
				next_state = s_start;
				
		// START : sample in the middle
		s_start:
			if (clock_counter == clk_cycle / 2 - 1) 
				next_state = (synced_data_bit == 1'b0) ? s_data_byte : s_idle;

		// DATA : shift in 8 bits, then go to parity
		s_data_byte:
			if (clock_counter == clk_cycle - 1 && bit_index == 3'd7) 
				next_state = s_parity_check;
				
		// PARITY : sample in the middle, then stop	
		s_parity_check:
			if (clock_counter == clk_cycle / 2 - 1) 
				next_state = s_stop;
		
		// STOP : sample at the end (full bit), then hold
		s_stop:
			if (clock_counter == clk_cycle - 1) 
				next_state = s_hold;
		
		// HOLD: wait for user to raise i_byte_accept
		s_hold:
			if (i_byte_accept) 			
				next_state = s_idle;
		
		default:
			next_state = s_idle;
	endcase
end

// FSM state update 
always @(posedge i_clk or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		current_state <= s_idle;
	else
		current_state <= next_state;
end

// Clock counter
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		clock_counter <= 8'd0;
	else if ((current_state == s_data_byte && clock_counter == clk_cycle - 1) || next_state != current_state) // End of one bit in s_data_byte or FSM changes states
		clock_counter <= 8'd0;
	else
		clock_counter <= clock_counter + 8'd1;
end

// Bit index counter
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		bit_index <= 3'd0;
	else if (current_state == s_data_byte && clock_counter == clk_cycle - 1)
		bit_index <= bit_index + 3'd1;
	else if (current_state != s_data_byte)
		bit_index <= 3'd0;
end

// Received bits buffer
always @(posedge i_clk or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		temp_data <= 8'd0;
	else if (current_state == s_data_byte && clock_counter == clk_cycle / 2 - 1)
		temp_data[bit_index] <= synced_data_bit;
end

// Parity check (even parity)
always @(posedge i_clk or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		parity_error <= 1'b0;
	else if (current_state ==s_idle && next_state==s_start)
		parity_error <= 1'b0;
	else if (current_state == s_parity_check && clock_counter == clk_cycle / 2 - 1)
		parity_error <= (^temp_data) != synced_data_bit;
end

// Framing error check
always @(posedge i_clk or negedge i_rst_n) 
begin
	if (i_rst_n == 1'b0)
		framing_error <= 1'b0;
	else if (current_state ==s_idle && next_state==s_start)
		framing_error <= 1'b0;
	else if (current_state == s_stop && clock_counter == clk_cycle - 1)
		framing_error <= (synced_data_bit != 1'b1);
end

// Output complete data byte
always @(posedge i_clk or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		o_data_byte <= 8'd0;
	else if (current_state == s_stop && next_state != current_state)
		o_data_byte <= temp_data;
end

// Done flag
always @(posedge i_clk or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		o_done <= 1'b0;
	else if (current_state == s_stop && next_state != current_state)
		o_done <= 1'b1;
	else if (current_state == s_hold && i_byte_accept == 1'b1)
		o_done <= 1'b0;
end

endmodule