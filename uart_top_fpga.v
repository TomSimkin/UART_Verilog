module uart_top_fpga #(parameter clksPerBit = 234)(
    input wire clk,
	input wire btnS1, 
	input wire btnS2,
    input wire dataRx,
    output wire dataTx,
	output reg [2:0] ledData
);

	// Button inversion (active-low)
	wire rst 			= ~btnS2;
	wire btnPressEnable = ~btnS1;
	
	// Internal wires
	wire 		rxFinished;
	wire [7:0] 	rxBits;
	wire 		parityError;
	wire 		btnEnable;
	wire [7:0] 	btnBits;
	reg 		enableTx;
	reg [7:0] 	bitsTx;
	reg [1:0] 	state; 

	// Priority logic: button send overrides FSM send
	wire uartEnableTx 	    = btnEnable | enableTx;
	wire [7:0] uartBitsTx 	= btnEnable ? btnBits : bitsTx;
	
	// State encoding 
	localparam WAIT_CMD 	= 2'b00; 	// Wait for a command from the PC
    localparam SEND_BYTE 	= 2'b01; 	// Initiate UART transmission
    localparam CLEANUP 		= 2'b10; 	// Reset control signals and return to wait 
	
    // UART transmitter
    uart_tx_fpga #(.clksPerBit(clksPerBit)) uut_tx (
        .i_clkTx(clk),
		.i_reset(rst),
        .i_enableTx(uartEnableTx),
		.i_bitsTx(uartBitsTx),
        .o_dataTx(dataTx),
        .o_doneTx()           
    );

    // UART receiver
    uart_rx_fpga #(.clksPerBit(clksPerBit)) uut_rx (
        .i_clkRx(clk),
        .i_txBit(dataRx),
        .o_rxFinished(rxFinished),
        .o_rxBits(rxBits),
        .o_parityError(parityError)
    );

	// Button debouncer 
	uart_button uut_btn (
		.clk(clk),
		.rst(rst),
		.btnPress(btnPressEnable),	// S1 (button on FPGA)
		.o_enableTx(btnEnable), 	// One-shot pulse
		.o_bitsTx(btnBits)		
	);

	// FSM to implement command-response
	always @(posedge clk or posedge rst) 
		begin
			if (rst)
				begin
					state <= WAIT_CMD;
					enableTx <= 0;
					bitsTx <= 0;
					ledData <= 3'b111;// All LEDs ON during reset
				end
			else
				begin
					case (state)
						WAIT_CMD:
							begin
								enableTx <= 0;
								ledData <= 3'b100; // LED2 ON - Idle 
								
								if (rxFinished) 
									begin
										case (rxBits)
											8'h41: // 'A'
												begin	
													bitsTx <= 8'h31;    // '1'	    
													ledData <= 3'b001;  // LED0 ON	
												end
											8'h42: // 'B' 
												begin
													bitsTx <= 8'h32;    // '2'  		
													ledData <= 3'b010;  // LED1 ON
												end
											default:
												begin
													bitsTx <= 8'h58;    // 'X' 
													ledData <= 3'b110;  // LED3 + LED2 ON = Error
												end
										endcase
										state <= SEND_BYTE;
									end
							end
						SEND_BYTE:
							begin
								enableTx <= 1;
								state <= CLEANUP;
							end
						CLEANUP:
							begin
								enableTx <= 0;
								ledData <= 3'b000;   // Clear LEDs
								state <= WAIT_CMD;
							end
					endcase
				end
			end
endmodule