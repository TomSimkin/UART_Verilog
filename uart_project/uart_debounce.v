module uart_debounce
#(
	parameter integer CLK_FREQ = 27_000_000, 	// 27 MHz clock
	parameter integer HOLD_MS  = 5				// Require 5 ms of stability
)
(
	input 	wire 	clk,		// System clock
	input 	wire 	rst_n,		// Asynchronous reset, low active
	input 	wire 	btn_press,	// Raw, unsynchronized button press
	output 	reg 	btn_result	// Debounced button press
);

localparam integer hold_max = (CLK_FREQ / 1000) * HOLD_MS; 	// HOLD_MS ms worth of clock cycles:
															// (CLK_FREQ / 1000) = 27_000 clocks per ms * HOLD_MS = 135_000 clocks per 5ms
															  
reg [17:0] counter; 		// Count cycles
reg 	   sync1, sync2;	// FF's (delays) to avoid metastability						  

// Synchronizer
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		sync1 <= 1'b1;
		sync2 <= 1'b1;
	end
	else
	begin
		sync1 <= btn_press;
		sync2 <= sync1;
	end
end

wire btn_debounced = sync2;

// Debounce counter 
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		counter <= 0;
		btn_result <= 1'b1;
	end
	else if (sync2 == btn_result)	// No change
		counter <= 0;
	else if (counter == hold_max) 	// Button held long enough
	begin
		btn_result <= btn_debounced;
		counter <= 0;
	end
	else
		counter <= counter + 18'd1;
end

endmodule