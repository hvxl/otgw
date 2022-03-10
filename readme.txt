Requirements
============

The provided files are intended to be used together with the GPUTILS tools.
GPUTILS can be downloaded from https://gputils.sourceforge.io/
A Makefile is provided to simplify building. To be able to use it, the GNU
make command must be available.

A Tcl interpreter is also needed to regenerate the "build.asm" file. This can
either be tclsh or a tclkit/tclkitsh.


Compiling
=========

To create a hex file that can be loaded into the PIC16F1847 using OTmonitor
or a PIC programmer, follow these steps:
- Unpack the tarball in a convenient location
- Run: make

The "build.asm" file is supposed to be auto-generated at the start of every
build. The included "build.tcl" script takes care of that. It is executed by
tclsh. If the tclsh executable is not in your PATH, pass the location to the
make command:
	make TCLSH=/path/to/tclsh
