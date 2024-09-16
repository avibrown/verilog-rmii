`timescale 1ns/1ps

module top_tb;

    // Inputs to the module
    reg clk;
    reg crs;
    reg [1:0] rx;
    reg mdio;

    // Outputs from the module
    wire tx_en;
    wire tx0;
    wire tx1;
    wire mdc;
    wire D5;

    // Instantiate the rmii module
    rmii uut (
        .clk_50MHz(clk),
        .CRS(crs),
        .RX0(rx[0]),
        .RX1(rx[1]),
        .MDIO(mdio),
        .TX_EN(tx_en),
        .TX0(tx0),
        .TX1(tx1),
        .MDC(mdc),
        .D5(D5)
    );

    // Clock generation: 50MHz clock (period of 20ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // Toggle every 10ns
    end

    // Initialize inputs
    initial begin
        crs  = 0;
        rx   = 2'b00;
        mdio = 0;
    end

    // Run the simulation long enough to observe TX outputs
    initial begin
        // Setup waveform dump
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        // Display messages when TX_EN is asserted
        $monitor("Time: %0t ns, TX_EN: %b, TX0: %b, TX1: %b", $time, tx_en, tx0, tx1);

        // Run simulation for sufficient time (e.g., 120ms)
        #120_000_00; // 120ms in nanoseconds
        $finish;
    end

endmodule
