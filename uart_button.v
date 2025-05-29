module uart_button (
    input        	 clk,
    input        	 rst,
    input        	 btnPress,       // S1 button input
    output reg   	 o_enableTx,
    output reg [7:0] o_bitsTx
);
    // Debounce parameters
    localparam 				debounceWidth = 18; // T = 1 / 27MHz = 37 ns , t_debounce = 2^n x T => n = 18 for 10ms debounce time
    reg [debounceWidth-1:0] debounceCounter = 0;
    reg 					btnSync1, btnSync2;
    reg 					btnStable, btnEdge; // btnStable - goes high only when button is held steadily, btnEdge - previous value of btnStable for edge detection

    // Synchronize button to clock domain
    always @(posedge clk) 
		begin
			btnSync1 <= btnPress;
			btnSync2 <= btnSync1;
		end

    // Debounce logic
    always @(posedge clk) 
		begin
			if (btnSync2) 
				begin
					if (debounceCounter < {debounceWidth{1'b1}})
						debounceCounter <= debounceCounter + 1'b1;
				end 
			else 
				begin
					debounceCounter <= 0;
			end
			
			btnStable <= (debounceCounter == {debounceWidth{1'b1}});
		end

    // Step 3: One-shot pulse on rising edge
    always @(posedge clk) 
		begin
			if (rst) 
				begin
					o_enableTx <= 0;
					o_bitsTx   <= 8'h00;
					btnEdge   <= 0;
				end 
				else 
					begin
						btnEdge <= btnStable;
						
						if (btnStable && !btnEdge) 
							begin
								o_enableTx <= 1;
								o_bitsTx   <= 8'h45; // ASCII 'E' - indicating enable
							end 
						else 
							o_enableTx <= 0;
					end
		end
		
endmodule
