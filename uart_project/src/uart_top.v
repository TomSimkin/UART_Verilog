module uart_top
(
	input 	wire CLK_27MHZ, 		// On-board 27 MHz oscillator 					(PIN 4)
	input 	wire RST_BTN_N, 		// On-board reset button, active-low 			(PIN 88)
	input 	wire BL616_UART_RX, 	// Data into FPGA receive input (i_data_bit) 	(PIN 69)
	output 	wire BL616_UART_TX, 	// Data from FPGA transmit output (o_tx) 		(PIN 70)
	output reg LED0, 				// Heartbeat (slow blink to know the FPGA is alive) (PIN 15)
	output reg LED1,				// Rx activity - pulse on every received byte		(PIN 16)
	output reg LED2,				// Tx activity - pulse on every transmitted byte	(PIN 17)
	output reg LED3					// Parity/framing error								(PIN 18)
);

// Clock and reset wiring
wire clk = CLK_27MHZ;
wire deb_btn;                   // when button goes high -> rst_n = 0
wire rst_n = ~deb_btn;			// Clean, debounced reset

// Rx signals
wire 		rx_done;			// Finished receiving data
wire [7:0] 	rx_data;			// Data storage 
wire 		rx_parity_err;		// Parity error flag
wire 		rx_framing_err; 	// Framing error flag
reg 		rx_ack;				// Accepted new data byte
reg 		error_detect;		// Error detection

// Tx signals
reg 	tx_valid;				// Pulse to start transmit of rx_data 
wire 	tx_ready;				// Ready to work on new byte, is idle

// Uart_rx instantiation 
uart_rx 
#(
	.clk_frequency(27), 		// 27 MHz 
	.baud_rate(115200)			// 115200 baud rate
)
RX
(
	.i_clk         (clk),
    .i_rst_n       (rst_n),
    .i_byte_accept (rx_ack),
    .i_data_bit    (BL616_UART_RX),
    .o_done        (rx_done),
    .o_data_byte   (rx_data),
    .parity_error  (rx_parity_err),
    .framing_error (rx_framing_err)
);

// Uart_tx instantiation 	
uart_tx
#(
	.clk_frequency(27), 		// 27 MHz 
	.baud_rate(115200)			// 115200 baud rate
)
TX
(
    .i_clk    	 (clk),
    .i_rst_n   	 (rst_n),
    .data_send 	 (rx_data),
    .tx_valid  	 (tx_valid),
    .ready_tx  	 (tx_ready),
    .o_tx      	 (BL616_UART_TX)
);

// Uart_debounce instantiation
uart_debounce
#(
	.CLK_FREQ	(27_000_000),
	.HOLD_MS 	(5)
)
DEBOUNCE
(
	.clk 	(clk),
	.rst_n 	(1'b1),         // Never reset internally, except by power-on
	.btn_press (RST_BTN_N), // Raw, active low-pushbutton
	.btn_result (deb_btn)
);

// Hand-shake register to clear the RX HOLD state
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    rx_ack <= 1'b0;
  else
    rx_ack <= rx_done;    // pulse high one cycle when rx_done pulses
end

//	Loopback controller, pulse TX for 1 clk on every rx_done
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    tx_valid <= 1'b0;
  else
    tx_valid <= rx_done;
end

// Heartbeat - LED0 1 Hz blink
reg [24:0] heart_counter;

always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		heart_counter <= 0;
		LED0 		  <= 1'b1;
	end
	else if (heart_counter == 27_000_000 - 1)
	begin
		heart_counter <= 0;
		LED0 <= ~LED0;
	end
	else
		heart_counter <= heart_counter + 25'd1;
end
	
// Rx + Tx pulses (LED1/LED2)
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		LED1 <= 1'b1;
		LED2 <= 1'b1;
	end
	else
	begin
		LED1 <= ~rx_done; 	// Lights 1 clk when a frame is received
		LED2 <= ~tx_valid;	// Light 1 clk when a frame is sent
	end
end

// Parity/framing error
// Latch error when it first occurs
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
		error_detect <= 1'b0;
	else if (rx_parity_err || rx_framing_err)	
		error_detect <= 1'b1;
end

// LED3: on during reset, afterwards follows error_detect
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
		LED3 <= 1'b1;
	else if (rx_parity_err || rx_framing_err)
		LED3 <= ~error_detect;
end

endmodule