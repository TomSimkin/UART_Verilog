module uart_top #(parameter clksPerBit = 87)(
    input wire clk,
    input wire enableTx,
    input wire [7:0] bitsTx,
    output wire dataTx,
    output wire rxFinished,
    output wire [7:0] rxBits,
    output wire parityError
);

    // UART Transmitter
    uart_tx #(.clksPerBit(clksPerBit)) uut_tx (
        .i_clkTx(clk),
        .i_enableTx(enableTx),
        .i_bitsTx(bitsTx),
        .o_dataTx(dataTx),
        .o_doneTx()           
    );

    // UART Receiver
    uart_rx #(.clksPerBit(clksPerBit)) uut_rx (
        .i_clkRx(clk),
        .i_txBit(dataTx),
        .o_rxFinished(rxFinished),
        .o_rxBits(rxBits),
        .o_parityError(parityError)
    );

endmodule