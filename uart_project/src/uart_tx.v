module uart_tx
#(
	parameter integer clk_frequency = 27, 	 // Clock frequency (27 MHz)
	parameter integer baud_rate 	= 115200 // Serial baud rate
)
(
	input		 	i_clk, 			// Clock input
	input 			i_rst_n, 		// Asynchronous reset input, low active
	input [7:0] 	data_send, 		// Data to send
	input 			tx_valid,		// Tx ready to send data 
	output reg		ready_tx,		// Tx ready to work on new byte, is idle
	output reg 		o_tx 			// Serial data output
	`ifdef SIM
	 , output reg [8:0] debug_frame // {Parity, Data} - used only in uart_tx_tb simulation
	`endif
);

localparam integer clk_cycle = (clk_frequency * 1000000) / baud_rate; // Number of FPGA clock cycles per UART bit period 

// State machine codes
localparam s_idle 	= 3'b000; // Idle state
localparam s_start 	= 3'b001; // Start bit
localparam s_send 	= 3'b010; // 8 Data bits
localparam s_parity = 3'b011; // Parity bit
localparam s_stop 	= 3'b100; // Stop bit

// Register decleration
reg [2:0] current_state, next_state; // States
reg [7:0] clock_counter; 			 // Clock cycle counter
reg [2:0] bit_index; 				 // Data bit location
reg [7:0] temp_data;				 // Temporary storage of data to be sent
reg 	  parity_bit;				 // Parity bit

// FSM next-state - combinational
always @(*)
begin
	// Default: hold current state (avoid latch)
	next_state = current_state;
	
	case (current_state)
		// IDLE: wait for start bit to go high 
		s_idle:
			if (tx_valid == 1'b1)
				next_state = s_start;
		
		// START: drive line low
		s_start:
			if (clock_counter == clk_cycle - 1)
				next_state = s_send;
		
		// SEND: send data byte
		s_send:
			if (clock_counter == clk_cycle - 1 && bit_index == 3'd7)
				next_state = s_parity;
		
		// PARITY: send parity bit
		s_parity:
			if (clock_counter == clk_cycle - 1)
				next_state = s_stop;
			
		// STOP: stop transmission, drive the line high 		
		s_stop:
			if (clock_counter == clk_cycle - 1)
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

// Ready for new byte handshake
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		ready_tx <= 1'b1;
	else if (current_state == s_idle)
		ready_tx <= !tx_valid;											// When tx_valid = 1, Rx is working on a byte, so ready_tx = 0
	else if (current_state == s_stop && clock_counter == clk_cycle - 1)
		ready_tx <= 1'b1;												// At end of stop bit, ready_tx <= '1'
end
	
// Clock cycle counter
always @(posedge i_clk or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		clock_counter <= 8'd0;
	else if (current_state != next_state || clock_counter == clk_cycle - 1) 
		clock_counter <= 8'd0;
	else
		clock_counter <= clock_counter + 8'd1;
end


// Bit index counter
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		bit_index <= 3'd0;
	else if (current_state == s_idle)
		bit_index <= 3'd0;
	else if (current_state == s_send && clock_counter == clk_cycle - 1)
		bit_index <= bit_index + 3'd1;
end

// Bits to send buffer
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		temp_data <= 8'd0;
	else if (current_state == s_idle && tx_valid == 1'b1)
		temp_data <= data_send;
end

// Latch data to buffer + compute parity bit
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
	begin
		temp_data  <= 8'd0;
		parity_bit <= 1'b0;
	end
	else if (current_state == s_idle && tx_valid == 1'b1)
	begin
		temp_data  <= data_send;
		parity_bit <= ^data_send;	// Even parity
	end
end

// Serial output
always @(posedge i_clk  or negedge i_rst_n)
begin
	if (i_rst_n == 1'b0)
		o_tx <= 1'b1;
	else
	begin
		case (current_state)
			// IDLE, STOP: send constant high
			s_idle, s_stop:
				o_tx <= 1'b1;
			
			// START: send 1 clk_cycle low
			s_start:
				o_tx <= 1'b0;
			
			// SEND: send temp_data byte
			s_send:
				o_tx <= temp_data[bit_index];		
			

			// PARITY: send parity bit
			s_parity:
				o_tx <= parity_bit;
				
			default: 
				o_tx <= 1'b1;
		endcase
	end
end

// Simulation debug port
`ifdef SIM
  always @(posedge i_clk or negedge i_rst_n) 
  begin
    if (i_rst_n == 1'b0)
      debug_frame <= 9'b0;
    else if (current_state == s_idle && tx_valid == 1'b1)
      debug_frame <= { parity_bit, data_send };
  end
`endif

endmodule