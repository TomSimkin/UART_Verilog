module uart_tx_fpga
	#(parameter clksPerBit = 234)
	(
		input 		i_clkTx,
		input 		i_reset,
		input 		i_enableTx,
		input [7:0] i_bitsTx,
		output reg 	o_dataTx, 
		output reg	o_doneTx
	);
	
// State machine decleration.

	localparam s_idleTx 		  	= 3'b000;
	localparam s_startTx 	  		= 3'b001;
	localparam s_dataTx		 		= 3'b010;
	localparam s_parityTx		 	= 3'b011;
	localparam s_stopTx 		  	= 3'b100;
	
	reg[2:0] r_currentStateTx;

// Other registers
	
	reg [7:0] r_clockCounterTx;
	reg [2:0] r_bitIndexTx;
	reg [7:0] r_dataBitsTx; 	 
	reg 	  r_parityTx;

	
	always @(posedge i_clkTx)
		begin
			if (i_reset)
				begin
					r_currentStateTx <= s_idleTx;
					o_dataTx         <= 1'b1;
					o_doneTx         <= 1'b0;
					r_clockCounterTx <= 0;
					r_bitIndexTx     <= 0;
					r_dataBitsTx     <= 0;
					r_parityTx       <= 0;
				end
			else
				begin
					case (r_currentStateTx)
						s_idleTx:
							begin
								o_dataTx 		 <= 1'b1;
								o_doneTx 		 <= 1'b0;
								r_clockCounterTx <= 0;
								r_bitIndexTx 	 <= 0;
								
								if (i_enableTx)
									begin
										r_dataBitsTx <= i_bitsTx;
										r_parityTx   <= ^i_bitsTx; // Even parity
										r_currentStateTx  <= s_startTx;
									end
							end
						s_startTx:
							begin
								o_dataTx <= 1'b0;
								
								if (r_clockCounterTx < clksPerBit - 1)
									r_clockCounterTx <= r_clockCounterTx + 1'b1;
								else
									begin
										r_clockCounterTx <= 0;
										r_currentStateTx <= s_dataTx;
									end
							end
						s_dataTx:
							begin
								o_dataTx <= r_dataBitsTx[r_bitIndexTx];
								
								if (r_clockCounterTx < clksPerBit - 1)
									r_clockCounterTx <= r_clockCounterTx + 1'b1;
								else
									begin
										r_clockCounterTx <= 0;
										
										if (r_bitIndexTx < 7)
											r_bitIndexTx <= r_bitIndexTx + 3'b001;
										else
											begin
												r_bitIndexTx <= 0;
												r_currentStateTx <= s_parityTx;
											end
									end
							end
						s_parityTx:
							begin
								o_dataTx <= r_parityTx;
								
								if (r_clockCounterTx < clksPerBit - 1)
									r_clockCounterTx <= r_clockCounterTx + 1'b1;
								else
									begin
										r_clockCounterTx <= 0;
										r_currentStateTx <= s_stopTx;
									end
							end
							s_stopTx:
								begin
									o_dataTx <= 1'b1;
									
									if (r_clockCounterTx < clksPerBit - 1)
										r_clockCounterTx <= r_clockCounterTx + 1'b1;
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
			end
		
endmodule