// SPI master, 8-bit, MSB first.
// SCLK = clk / 10 (sclk toggles every 5 system clocks while in TRANSFER).
module spi_master (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       miso,
    input  wire       start,
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,
    output reg        mosi,
    output reg        sclk,
    output reg        busy,
    output reg        cs_n
);

    // FSM states
    localparam [1:0] IDLE     = 2'b00;
    localparam [1:0] LOAD     = 2'b01;
    localparam [1:0] TRANSFER = 2'b10;
    localparam [1:0] DONE     = 2'b11;

    reg [1:0] state;
    reg [2:0] bit_count;
    reg [2:0] clk_div_count;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;

    // Clock divider: generates SCLK only while a transfer is running
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk          <= 1'b0;
            clk_div_count <= 3'd0;
        end else if (state != TRANSFER) begin
            sclk          <= 1'b0;
            clk_div_count <= 3'd0;
        end else if (clk_div_count == 3'd4) begin
            sclk          <= ~sclk;
            clk_div_count <= 3'd0;
        end else begin
            clk_div_count <= clk_div_count + 3'd1;
        end
    end

    // Control FSM + shift registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            busy      <= 1'b0;
            cs_n      <= 1'b1;
            bit_count <= 3'd0;
            tx_shift  <= 8'd0;
            rx_shift  <= 8'd0;
            rx_data   <= 8'd0;
            mosi      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= 1'b1;
                    busy <= 1'b0;
                    if (start == 1'b1) begin
                        tx_shift <= tx_data;
                        state    <= LOAD;
                    end
                end

                LOAD: begin
                    cs_n      <= 1'b0;
                    busy      <= 1'b1;
                    bit_count <= 3'd0;
                    mosi      <= tx_data[7];
                    state     <= TRANSFER;
                end

                TRANSFER: begin
                    if (clk_div_count == 3'd4 && sclk == 1'b0) begin
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        mosi     <= tx_shift[7];
                    end
                    if (clk_div_count == 3'd4 && sclk == 1'b0) begin
                        rx_shift  <= {rx_shift[6:0], miso};
                        bit_count <= bit_count + 3'd1;
                        if (bit_count == 3'd7)
                            state <= DONE;
                    end
                end

                DONE: begin
                    cs_n    <= 1'b1;
                    busy    <= 1'b0;
                    rx_data <= rx_shift;
                    state   <= IDLE;
                end

                default: ;
            endcase
        end
    end

endmodule
