# -*- make -*-

SCRIPT = 16f1847.lkr
PROJECT = gateway
OTGWOBJECTS = gateway.o ds1820.o selfprog.o
DIAGOBJECTS = diagnose.o selfprog.o
OUTPUT = $(PROJECT).hex
COD = $(PROJECT).cod
GPASM = gpasm
GPLINK = gplink
GPSIM = gpsim
TCLSH = tclsh

$(OUTPUT) $(COD): $(OTGWOBJECTS) $(SCRIPT)
	$(GPLINK) --map -s $(SCRIPT) -o $@ $(OTGWOBJECTS)

diagnose.hex: $(DIAGOBJECTS) $(SCRIPT)
	$(GPLINK) --map -s $(SCRIPT) -o $@ $(DIAGOBJECTS)

%.o: %.asm
	$(GPASM) $(CFLAGS) -c $<

gateway.o: build.asm

build.asm: gateway.asm ds1820.asm
	$(TCLSH) tools/build.tcl

test: $(COD)
	GPSIM=$(GPSIM) $(TCLSH) tests/all.tcl $(TESTFLAGS)

clean:
	rm -f *~ *.o *.lst *.map *.hex *.cod

.PHONY: clean test

# # Include a local make file, if it exists
-include Makefile-local.mk
