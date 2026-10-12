`timescale 1ns/1ps

// Self-checking testbench for spi_master + spi_slave.
// Prints ALL TESTS PASSED, or TOTAL MISMATCHES: <n>.
module spi_tb;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] master_tx_data;
    reg  [7:0] slave_tx_data;
    wire [7:0] master_rx_data;
    wire [7:0] slave_rx_data;
    wire       busy;
    wire       cs_n_wire;
    wire       sclk_wire;
    wire       mosi_wire;
    wire       miso_wire;

    integer error_count;

    spi_master master (
        .clk    (clk),
        .rst_n  (rst_n),
        .miso   (miso_wire),
        .start  (start),
        .tx_data(master_tx_data),
        .rx_data(master_rx_data),
        .mosi   (mosi_wire),
        .sclk   (sclk_wire),
        .busy   (busy),
        .cs_n   (cs_n_wire)
    );

    spi_slave slave (
        .cs_n   (cs_n_wire),
        .sclk   (sclk_wire),
        .mosi   (mosi_wire),
        .rst_n  (rst_n),
        .tx_data(slave_tx_data),
        .rx_data(slave_rx_data),
        .miso   (miso_wire)
    );

    initial error_count = 0;

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // One full-duplex transfer, then compare both directions
    task do_transfer;
        input [7:0] m_tx;
        input [7:0] s_tx;
        begin
            master_tx_data = m_tx;
            slave_tx_data  = s_tx;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            wait (busy == 1'b1);
            wait (busy == 1'b0);
            #20;

            $display("time = %0t master_sent = %h slave_sent = %h master_rx = %h slave_rx = %h",
                     $time, m_tx, s_tx, master_rx_data, slave_rx_data);

            if (master_rx_data !== s_tx) begin
                $display("MISMATCH : master_rx_data (%h) != expected slave_tx(%h)",
                         master_rx_data, s_tx);
                error_count = error_count + 1;
            end
            if (slave_rx_data !== m_tx) begin
                $display("  MISMATCH: slave_rx_data (%h) != expected master_tx (%h)",
                         slave_rx_data, m_tx);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_tb);

        rst_n          = 1'b0;
        start          = 1'b0;
        master_tx_data = 8'h00;
        slave_tx_data  = 8'h00;

        #20 rst_n = 1'b1;
        #20;

        do_transfer(8'hA5, 8'h3C);
        #40;
        do_transfer(8'hFF, 8'h00);
        #40;
        do_transfer(8'h00, 8'hFF);
        #40;
        do_transfer(8'h5A, 8'hC3);
        #40;

        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TOTAL MISMATCHES: %0d", error_count);

        #50 $finish;
    end

endmodule
