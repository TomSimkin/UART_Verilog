module uart_rx_fpga
	#(parameter clksPerBit = 234)
	(
		input 			 i_clkRx,
		input 		 	 i_txBit,
		output 	reg		 o_rxFinished,
		output 	[7:0] 	 o_rxBits,
		output 	reg		 o_parityError
	);

// State machine decleration.

	localparam s_idleRx 		= 3'b000;
	localparam s_startRx 	  	= 3'b001;
	localparam s_receiveDataRx 	= 3'b010;
	localparam s_checkParityRx 	= 3'b011;
	localparam s_stopRx 		= 3'b100;
	localparam s_holdRx		  	= 3'b101;
	
	reg[2:0] r_currentStateRx;
	
// FF registers - to avoid problems caused by metastability.
// Using 2 FF guarantees 2 CC delay -> transitioning to Rx clock domain.

	reg r_ff1;
	reg r_rxData;
	
// Other registers
	
	reg [7:0] r_clockCounter;
	reg [3:0] r_bitIndex;
	reg [8:0] r_rxBits;
	reg 	  r_parityCheck; 
	integer   r_resCounter;
	
// 2 CC delay

	always @(posedge i_clkRx)
		begin
			r_ff1 	 <= i_txBit;
			r_rxData <= r_ff1;
		end
	
	always @(posedge i_clkRx)
		begin
			case (r_currentStateRx)
				s_idleRx:
					begin
						o_rxFinished   	<= 1'b0;
						r_clockCounter 	<= 0;
						r_bitIndex 	   	<= 0;
						r_rxBits 	   	<= 0;
						r_parityCheck 	<= 1'b0;
						o_parityError 	<= 1'b0;
						r_resCounter 	<= 0;
						
						if (r_rxData == 1'b0) 
							r_currentStateRx <= s_startRx;
					end
				s_startRx:
					begin 
						if (r_clockCounter == clksPerBit / 2) // Check if we are in the middle of the start bit 
							begin
								if (r_rxData == 1'b0) // Check if start is still low
									begin
										r_clockCounter 	 <= 0;
										r_currentStateRx <= s_receiveDataRx;
									end 
								else 
									r_currentStateRx <= s_idleRx;
							end
						else
							r_clockCounter <= r_clockCounter + 1'b1; // If not in the middle, increase counter by 1
						end
				s_receiveDataRx:
					begin
						if (r_clockCounter < clksPerBit - 1) // Checking from middle of last bit to middle of current bit
							r_clockCounter <= r_clockCounter + 1'b1;
						else
							begin
								r_clockCounter <= 0;
								r_rxBits[r_bitIndex] <= r_rxData;
								if (r_bitIndex == 8) // Parity bit check
									begin
										r_bitIndex 		 <= 0;
										r_parityCheck    <= ^r_rxBits[8:1];
										r_currentStateRx <= s_checkParityRx;
									end
								else
									r_bitIndex <= r_bitIndex + 1'b1;
							end
					end
				s_checkParityRx:
					begin
						if (r_parityCheck == r_rxBits[0])
							o_parityError <= 1'b0;
						else
							o_parityError <= 1'b1;
							
						r_parityCheck 	 <= 1'b0;
						r_currentStateRx <= s_stopRx;
					end
				s_stopRx:
					begin
						if (r_clockCounter < clksPerBit - 1)
							r_clockCounter <= r_clockCounter + 1'b1;
						else
							begin
								r_clockCounter 	 <= 0;
								
								if (r_rxData != 1'b1)	// Check stop bit
									o_parityError <= 1'b1;
									
								o_rxFinished 	 <= 1'b1;
								r_currentStateRx <= s_holdRx;
							end
					end
				s_holdRx:
					begin
						if (r_resCounter == clksPerBit / 2)
							begin
								r_currentStateRx <= s_idleRx;
								o_rxFinished 	 <= 1'b0;
								r_resCounter 	 <= 0;
							end
						else
							r_resCounter <= r_resCounter + 1;
					end
				default:
					r_currentStateRx <= s_idleRx;
					
			endcase
		end
		
	assign o_rxBits = r_rxBits[8:1];
		
endmodule