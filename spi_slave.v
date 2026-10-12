// SPI slave, 8-bit, MSB first. Clocked by the incoming SCLK.
module spi_slave (
    input  wire       cs_n,
    input  wire       sclk,
    input  wire       mosi,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,
    output reg        miso
);

    reg [2:0] bit_count;
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;

    // When chip select asserts: load the byte to send and present its MSB
    always @(negedge rst_n or negedge cs_n) begin
        if (!rst_n) begin
            tx_shift <= 8'd0;
            miso     <= 1'b0;
        end else begin
            tx_shift <= tx_data;
            miso     <= tx_data[7];
        end
    end

    // On each SCLK falling edge: shift out the next bit
    always @(negedge rst_n or negedge sclk) begin
        if (!rst_n) begin
            tx_shift <= 8'd0;
            miso     <= 1'b0;
        end else if (!cs_n) begin
            tx_shift <= {tx_shift[6:0], 1'b0};
            miso     <= tx_shift[6];
        end
    end

    // On each SCLK rising edge: shift in MOSI; latch the byte after 8 bits
    always @(negedge rst_n or posedge sclk) begin
        if (!rst_n) begin
            rx_data   <= 8'd0;
            rx_shift  <= 8'd0;
            bit_count <= 3'd0;
        end else if (!cs_n) begin
            rx_shift  <= {rx_shift[6:0], mosi};
            bit_count <= bit_count + 3'd1;
            if (bit_count == 3'd7) begin
                rx_data   <= {rx_shift[6:0], mosi};
                bit_count <= 3'd0;
            end
        end
    end

endmodule
