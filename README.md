# SPI Master & Slave in Verilog

An 8-bit, full-duplex SPI master and slave written in Verilog (behavioral RTL), with a self-checking testbench simulated in Icarus Verilog.

## Features

- SCLK idles low (CPOL = 0), MSB first, 8-bit frames
- FSM-based master (`IDLE → LOAD → TRANSFER → DONE`)
- Configurable-by-constant clock divider: `SCLK = clk / 10`
- Active-low asynchronous reset and active-low chip select
- Full duplex: master and slave exchange a byte in the same transfer
- Self-checking testbench that reports `ALL TESTS PASSED` or the number of mismatches
- One-command simulation (`make run`) and GitHub Actions CI

## Repository layout

```
.
├── rtl/
│   ├── spi_master.v      # SPI master (FSM + clock divider + shift registers)
│   └── spi_slave.v       # SPI slave (shift registers clocked by SCLK)
├── tb/
│   └── spi_tb.v          # Self-checking testbench
├── docs/
│   └── waveform.png      # GTKWave screenshot (add yours here)
├── .github/workflows/
│   └── sim.yml           # CI: runs the simulation on every push
├── Makefile
├── LICENSE
└── README.md
```

## Interface

### `spi_master`

| Port      | Dir | Width | Description                                  |
|-----------|-----|-------|----------------------------------------------|
| `clk`     | in  | 1     | System clock                                 |
| `rst_n`   | in  | 1     | Active-low reset                             |
| `start`   | in  | 1     | Pulse high for one clock to begin a transfer |
| `tx_data` | in  | 8     | Byte to transmit (sampled when `start` seen) |
| `miso`    | in  | 1     | Serial data from slave                       |
| `rx_data` | out | 8     | Byte received (valid after transfer ends)    |
| `mosi`    | out | 1     | Serial data to slave                         |
| `sclk`    | out | 1     | SPI clock (`clk / 10`)                       |
| `cs_n`    | out | 1     | Active-low chip select                       |
| `busy`    | out | 1     | High while a transfer is in progress         |

### `spi_slave`

| Port      | Dir | Width | Description                       |
|-----------|-----|-------|-----------------------------------|
| `cs_n`    | in  | 1     | Active-low chip select            |
| `sclk`    | in  | 1     | SPI clock from master             |
| `mosi`    | in  | 1     | Serial data from master           |
| `rst_n`   | in  | 1     | Active-low reset                  |
| `tx_data` | in  | 8     | Byte to send back to the master   |
| `rx_data` | out | 8     | Byte received from the master     |
| `miso`    | out | 1     | Serial data to master             |

## How it works

**Master FSM**

| State      | Action                                                              |
|------------|---------------------------------------------------------------------|
| `IDLE`     | `cs_n` high, `busy` low. Waits for `start`, latches `tx_data`.      |
| `LOAD`     | Asserts `cs_n` low and `busy`, drives the MSB onto `mosi`.          |
| `TRANSFER` | On each `SCLK` rising edge the master shifts out the next bit and samples `miso`. Counts 8 bits. |
| `DONE`     | Deasserts `cs_n` and `busy`, copies the shift register into `rx_data`. |

**Timing:** a counter toggles `sclk` every 5 system clocks, so with a 100 MHz clock `SCLK` is 10 MHz. The slave shifts in `mosi` on the `SCLK` rising edge and updates `miso` on the falling edge. The master updates `mosi` and samples `miso` on the same rising-edge tick that it toggles `sclk` (see Limitations).

## Running the simulation

Requirements: [Icarus Verilog](https://steveicarus.github.io/iverilog/) (and optionally GTKWave).

```bash
make run     # compile and simulate, fails if any test mismatches
make wave    # open the waveform in GTKWave
make clean
```

Expected output (timestamps will vary):

```
time = ... master_sent = a5 slave_sent = 3c master_rx = 3c slave_rx = a5
time = ... master_sent = ff slave_sent = 00 master_rx = 00 slave_rx = ff
time = ... master_sent = 00 slave_sent = ff master_rx = ff slave_rx = 00
time = ... master_sent = 5a slave_sent = c3 master_rx = c3 slave_rx = 5a
ALL TESTS PASSED
```

## Test coverage

| # | Master TX | Slave TX | Purpose                  |
|---|-----------|----------|--------------------------|
| 1 | `0xA5`    | `0x3C`   | Alternating bit patterns |
| 2 | `0xFF`    | `0x00`   | All ones vs. all zeros   |
| 3 | `0x00`    | `0xFF`   | Reverse of the above     |
| 4 | `0x5A`    | `0xC3`   | Mixed patterns           |

After each transfer the testbench checks that `master_rx_data == slave_tx_data` and `slave_rx_data == master_tx_data`.

## Waveform

![SPI waveform](docs/waveform.png)

## Limitations / future work

- The master changes `mosi` on the same clock edge that `sclk` rises, so the slave relies on simulation event ordering to see the new bit. It passes in Icarus Verilog but is not proper Mode 0 timing for real hardware; fix by moving the `mosi` update to the `sclk` falling edge
- The slave updates `tx_shift`/`miso` from two `always` blocks and is clocked by `sclk`, so it is simulation-oriented and not directly synthesizable
- CPOL/CPHA are not configurable
- Fixed 8-bit frame length and fixed clock divider
- Single slave select line
- Add randomized tests and protocol assertions
- Add parameters for data width, clock divider and SPI mode
- FPGA implementation and resource/timing report

## License

MIT, see [LICENSE](LICENSE).
