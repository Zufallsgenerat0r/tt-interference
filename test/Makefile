# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v

# oss-cad-suite's vvp embeds Python 3.11 with its own site-packages.
# Set PYTHONPATH so the embedded Python finds our venv's cocotb.
# Set LIBPYTHON_LOC to the actual dylib (sysconfig reports broken build-time paths).
VENV_SITE_PACKAGES := $(shell python3 -c 'import site; print(site.getsitepackages()[0])' 2>/dev/null)
ifdef VENV_SITE_PACKAGES
  export PYTHONPATH := $(VENV_SITE_PACKAGES)
endif
PYTHON_BASE_PREFIX := $(shell python3 -c 'import sys; print(sys.base_prefix)' 2>/dev/null)
LIBPYTHON_CANDIDATE := $(wildcard $(PYTHON_BASE_PREFIX)/lib/libpython*.dylib $(PYTHON_BASE_PREFIX)/lib/libpython*.so)
ifdef LIBPYTHON_CANDIDATE
  export LIBPYTHON_LOC := $(firstword $(LIBPYTHON_CANDIDATE))
endif

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
