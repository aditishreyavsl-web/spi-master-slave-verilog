IVERILOG ?= iverilog
VVP      ?= vvp
BUILD    := build
SRCS     := rtl/spi_master.v rtl/spi_slave.v tb/spi_tb.v

.PHONY: all sim run wave clean

all: run

$(BUILD)/sim.out: $(SRCS)
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -Wall -Wno-timescale -o $@ $(SRCS)

sim: $(BUILD)/sim.out

# Run the simulation; fail if the testbench does not report success.
run: sim
	cd $(BUILD) && $(VVP) sim.out | tee sim.log
	@grep -q "ALL TESTS PASSED" $(BUILD)/sim.log || (echo "SIMULATION FAILED"; exit 1)

wave: run
	gtkwave $(BUILD)/spi_tb.vcd &

clean:
	rm -rf $(BUILD)
