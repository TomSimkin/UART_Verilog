module uart_tx
	#(parameter clksPerBit)
	(
		input 		i_clkTx,
		input 		i_enableTx,
		input [7:0] i_bitsTx,
		output reg 	o_dataTx, 
		output reg	o_doneTx
	);
	
// State machine decleration.

	localparam s_idleTx 		  	= 3'b000;
	localparam s_startTx 	  		= 3'b001;
	localparam s_sendParityTx 		= 3'b010;
	localparam s_transmitDataTx 	= 3'b011;
	localparam s_stopTx 		  	= 3'b100;
	
	reg[2:0] r_currentStateTx = 0;

// Other registers
	
	reg [7:0] r_clockCounterTx 	= 0;
	reg [3:0] r_bitIndexTx 	 	= 0;
	reg [8:0] r_dataBitsTx 	 	= 0; 	 // 8 data bits + 1 parity bit
	reg r_parityTx    	 	 	= 1'b0;  // Even parity: 0 - correct, 1 - error
	reg r_txFinished  		 	= 1'b0;
	reg r_parityErrorTx 	 	= 1'b0;
	
	always @(posedge i_clkTx)
		begin
			case (r_currentStateTx)
				s_idleTx:
					begin
						o_dataTx 		 <= 1'b1;
						o_doneTx 		 <= 1'b0;
						r_clockCounterTx <= 0;
						r_bitIndexTx 	 <= 4'b0001;
						r_dataBitsTx	 <= 0;
						r_parityTx 		 <= 1'b0;
						r_txFinished 	 <= 1'b0;
						r_parityErrorTx  <= 1'b0;
						
						if (i_enableTx == 1'b1)
							begin
								r_dataBitsTx[8:1] <= i_bitsTx;
								r_dataBitsTx[0]   <= ^i_bitsTx; // Parity bit calculation
								r_currentStateTx  <= s_startTx;
							end
					end
				s_startTx:
					begin
						o_dataTx <= 1'b0;
						
						if (r_clockCounterTx < clksPerBit - 1)
							r_clockCounterTx <= r_clockCounterTx + 1;
						else
							begin
								r_clockCounterTx <= 0;
								r_currentStateTx <= s_sendParityTx;
							end
					end
				s_sendParityTx:
						begin
							o_dataTx <= r_dataBitsTx[0];
							
							if (r_clockCounterTx < clksPerBit - 1)
								r_clockCounterTx <= r_clockCounterTx + 1;
							else
								begin
									r_parityTx <= 1'b0;
									r_clockCounterTx <= 0;
									r_currentStateTx <= s_transmitDataTx;
								end
						end
				s_transmitDataTx:
					begin
						if (r_bitIndexTx < 9)
							begin
								o_dataTx <= r_dataBitsTx[r_bitIndexTx];
								
								if (r_clockCounterTx < clksPerBit - 1)
									r_clockCounterTx <= r_clockCounterTx + 1;
								else
									begin
										r_clockCounterTx <= 0;
										r_bitIndexTx <= r_bitIndexTx + 1;
									end
							end		
						else
							r_currentStateTx <= s_stopTx;
					end
					s_stopTx:
						begin
							o_dataTx <= 1'b1;
							
							if (r_clockCounterTx < clksPerBit - 1)
								r_clockCounterTx <= r_clockCounterTx + 1;
							else
								begin
									r_clockCounterTx <= 0;
									o_doneTx <= 1'b1;
									r_currentStateTx <= s_idleTx;
								end
						end
					default:
						r_currentStateTx <= s_idleTx;
			endcase
		end
		
endmodule