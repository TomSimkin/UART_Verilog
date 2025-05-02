# UART Implementation in Verilog

This project contains a complete **half-duplex UART transceiver** written in Verilog, designed to run on FPGA development boards. 

It includes transmitter (Tx), receiver (Rx), and integrated testbenches for validation.

## Features

- 📡 **Half-Duplex UART** – share a single line for Tx/Rx
- 🔁 **Baud Rate:** 115200 (with 10 MHz clock input)
- 🧱 **Frame Format:**  
  - 1 Start Bit (LOW)  
  - 8 Data Bits  
  - 1 Even Parity Bit  
  - 1 Stop Bit (HIGH)  
- 🔍 **Parity Error Detection** (Rx side)
- 🧪 **Three Testbenches:**
  - Tx Testbench
  - Rx Testbench
  - Integrated UART Testbench

## Simulation Notes

- Each UART frame is 11 bits long (start + 8 data + parity + stop).
- Total frame time ≈ 95.7 µs
- Recommended simulation time: ≥ 2 × frame duration to ensure capture.

## Hardware

Tested on:  
🔌 **Sipeed Tang Nano 20K FPGA Board**  
[Buy on AliExpress](https://www.aliexpress.com/item/1005007678286393.html)

## Accuracy

- Measured Baud Rate: ~114,631 bps  
- Error: ~0.5% (well within the 2% UART tolerance)

For questions or suggestions, feel free to reach out!
