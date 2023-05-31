

# library name
lib.name = externals.howto.luagran

# input source file (class name == source file basename)
class.sources = luagran~.c

# all extra files to be included in binary distribution of the library
datafiles =

cflags = -Ilua/
ldlibs = -L./lua/ -llua

# include Makefile.pdlibbuilder from submodule directory 'pd-lib-builder'
PDLIBBUILDER_DIR=../../pd-lib-builder/
include $(PDLIBBUILDER_DIR)/Makefile.pdlibbuilder