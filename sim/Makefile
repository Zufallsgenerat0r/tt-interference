SOURCES = main.cpp sc_time_stamp.cpp
TOP_MODULE := $(shell awk -F'"' '/top_module:/ {print $$2}' ../info.yaml)
PROJECT_CLOCK_HZ := $(shell awk '/clock_hz:/ {print $$2; exit}' ../info.yaml)
VGA_CLOCK_HZ ?= 25175000
DUT_CLOCKS_PER_PIXEL ?= $(shell python3 -c 'import sys; p=int(sys.argv[1] or 0); v=int(sys.argv[2]); print(max(1, round(p / v)))' "$(PROJECT_CLOCK_HZ)" "$(VGA_CLOCK_HZ)")
VERILOG_SOURCES := $(shell sed -n 's/.*- "\(.*\)".*/..\/src\/\1/p' ../info.yaml | xargs)
OBJ_DIR := obj_dir
LANGUAGE := --default-language 1364-2005
SIM_ARGS ?= --polarity
GIF_FRAMES ?= 128
VIDEO_SECONDS ?= 30
VIDEO_FPS ?= 50
VIDEO_OUTPUT ?= output.mp4
VIDEO_FRAMES ?= $(shell python3 -c 'print(int(round(float("$(VIDEO_SECONDS)") * float("$(VIDEO_FPS)"))))')

SDL_CFLAGS := $(shell sdl2-config --cflags 2>/dev/null)
SDL_LDFLAGS := $(shell sdl2-config --libs 2>/dev/null)

VFLAGS = -Wall -Wpedantic $(LANGUAGE) --x-assign fast --x-initial fast --noassert --top-module $(TOP_MODULE)
CFLAGS = -flto -O3 -march=native -DTOP_MODULE=V$(TOP_MODULE) -DDUT_CLOCKS_PER_PIXEL=$(DUT_CLOCKS_PER_PIXEL) -I$(OBJ_DIR) -I$(abspath ../vga_sim) $(SDL_CFLAGS) -include V$(TOP_MODULE).h
LDFLAGS = -flto $(SDL_LDFLAGS)

all: $(OBJ_DIR)/V$(TOP_MODULE).h
	make -C $(OBJ_DIR) -f V$(TOP_MODULE).mk

$(OBJ_DIR)/V$(TOP_MODULE).h: $(VERILOG_SOURCES) $(SOURCES)
	verilator $(VFLAGS) --cc $(VERILOG_SOURCES) --exe $(SOURCES) -CFLAGS "$(CFLAGS)" -LDFLAGS "$(LDFLAGS)"

lint: $(VERILOG_SOURCES)
	verilator --lint-only $(VFLAGS) $(VERILOG_SOURCES)

sim: all
	$(OBJ_DIR)/V$(TOP_MODULE) $(SIM_ARGS)

gif: all
	$(OBJ_DIR)/V$(TOP_MODULE) $(SIM_ARGS) --gif $(GIF_FRAMES)

video: all
	$(OBJ_DIR)/V$(TOP_MODULE) $(SIM_ARGS) --gif $(VIDEO_FRAMES)
	ffmpeg -y -v warning -i output.gif -t $(VIDEO_SECONDS) -vf "fps=$(VIDEO_FPS),format=yuv420p" -movflags +faststart $(VIDEO_OUTPUT)

clean:
	rm -rf $(OBJ_DIR)
	rm -f output.gif
	rm -f output.mp4

distclean: clean

.PHONY: all lint sim gif video clean distclean
