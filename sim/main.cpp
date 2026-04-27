// Copyright 2026 Kilian
//
// Licensed under the Apache License, Version 2.0.
//
// Repo-local Tiny Tapeout VGA simulator entry point. This is derived from
// jar/vga_sim's main loop, with support for designs whose DUT clock is an
// integer multiple of the VGA pixel clock.

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#include <SDL.h>
#include "gif.h"
#include "verilated.h"
#include "vga_timings.hpp"

#ifndef DUT_CLOCKS_PER_PIXEL
#define DUT_CLOCKS_PER_PIXEL 1
#endif

struct ABGR8888_t {
  uint8_t r, g, b, a;
} __attribute__((packed));

union VGApinout_t {
  uint8_t pins;
  struct {
    uint8_t r1 : 1;
    uint8_t g1 : 1;
    uint8_t b1 : 1;
    uint8_t vsync : 1;
    uint8_t r0 : 1;
    uint8_t g0 : 1;
    uint8_t b0 : 1;
    uint8_t hsync : 1;
  } __attribute__((packed));
};

static void tick(TOP_MODULE *top, bool reset_active, uint8_t ui_in) {
  top->rst_n = reset_active ? 0 : 1;
  top->ui_in = ui_in;
  top->clk = 0;
  top->eval();

  top->rst_n = reset_active ? 0 : 1;
  top->ui_in = ui_in;
  top->clk = 1;
  top->eval();
}

static VGApinout_t tick_pixel(
    TOP_MODULE *top,
    int dut_clocks_per_pixel,
    int sample_clock,
    bool reset_active,
    uint8_t ui_in) {
  VGApinout_t sampled{0};
  for (int clock = 0; clock < dut_clocks_per_pixel; ++clock) {
    tick(top, reset_active, ui_in);
    if (clock == sample_clock) {
      sampled.pins = top->uo_out;
    }
  }
  if (sample_clock >= dut_clocks_per_pixel) {
    sampled.pins = top->uo_out;
  }
  return sampled;
}

static void print_help(
    Uint32 fullscreen,
    bool polarity,
    bool slow,
    int dut_clocks_per_pixel,
    int sample_clock,
    int gif_frames,
    size_t mode_count) {
  printf("Command Line                    | [Key]\n");
  printf("  --fullscreen                  | [ F ]  Toggles SDL window size (default: %s)\n", fullscreen ? "maximized" : "minimized");
  printf("  --polarity                    | [ P ]  Toggles the VGA polarity sync high/low (default: %s)\n", polarity ? "true" : "false");
  printf("  --slow                        | [ S ]  Toggles the displayed frame rate (default: %s)\n", slow ? "true" : "false");
  printf("  --mode [#]                             Sets SDL VGA timing mode (value: [0:%zu])\n", mode_count - 1);
  printf("  --dut-clocks-per-pixel [#]             DUT clocks per VGA pixel (default: %d)\n", dut_clocks_per_pixel);
  printf("  --sample-clock [#]                     DUT sub-clock sampled for VGA output (default: %d)\n", sample_clock);
  printf("  --gif [#frames]                        Saves animated GIF (default frames: %d)\n", gif_frames);
  printf("                                | [ Q ]  Quits/Escapes (stops GIF if enabled).\n");
}

int main(int argc, char **argv) {
  static Uint32 fullscreen = 0;
  bool polarity = false;
  bool slow = false;
  bool gif = false;
  int gif_frames = 0;
  int dut_clocks_per_pixel = DUT_CLOCKS_PER_PIXEL;
  int sample_clock = 0;
  std::vector<vga_format> modes{
      VGA_640_480_60, VGA_768_576_60, VGA_800_600_60, VGA_1024_768_60};
  vga_timing mode = vga_timings[modes[0]];

  for (int i = 1; i < argc; ++i) {
    char *p = argv[i];
    if (!strcmp("--", p)) {
      break;
    } else if (!strcmp("--fullscreen", p)) {
      fullscreen = fullscreen ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP;
    } else if (!strcmp("--polarity", p)) {
      polarity = !polarity;
    } else if (!strcmp("--slow", p)) {
      slow = !slow;
    } else if (!strcmp("--mode", p)) {
      if (i + 1 < argc) {
        int m = atoi(argv[++i]);
        if (m >= 0 && m < static_cast<int>(modes.size())) {
          mode = vga_timings[modes[m]];
        }
      }
    } else if (!strcmp("--dut-clocks-per-pixel", p)) {
      if (i + 1 < argc) {
        dut_clocks_per_pixel = std::max(1, atoi(argv[++i]));
      }
    } else if (!strcmp("--sample-clock", p)) {
      if (i + 1 < argc) {
        sample_clock = std::max(0, atoi(argv[++i]));
      }
    } else if (!strcmp("--gif", p)) {
      gif = true;
      if (i + 1 < argc) {
        gif_frames = atoi(argv[++i]);
      }
    } else {
      print_help(
          fullscreen,
          polarity,
          slow,
          dut_clocks_per_pixel,
          sample_clock,
          gif_frames,
          modes.size());
      return 1;
    }
  }

  if (sample_clock >= dut_clocks_per_pixel) {
    sample_clock = dut_clocks_per_pixel - 1;
  }

  vga_timing vga = mode;
  std::vector<ABGR8888_t> fb(vga.h_active_pixels * vga.v_active_lines);

  GifWriter g;
  int delay = ceilf(vga.frame_cycles() / (vga.clock_mhz * 10000.f));
  if (gif) {
    GifBegin(&g, "output.gif", vga.h_active_pixels, vga.v_active_lines, delay);
  }

  SDL_Init(SDL_INIT_VIDEO);
  SDL_Window *w = SDL_CreateWindow(
      "Tiny Tapeout VGA",
      SDL_WINDOWPOS_CENTERED,
      SDL_WINDOWPOS_CENTERED,
      vga.h_active_pixels,
      vga.v_active_lines,
      SDL_WINDOW_RESIZABLE | fullscreen);
  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "best");
  SDL_Renderer *r = SDL_CreateRenderer(w, -1, SDL_RENDERER_ACCELERATED);
  SDL_RenderSetLogicalSize(r, vga.h_active_pixels, vga.v_active_lines);
  SDL_Texture *t = SDL_CreateTexture(
      r,
      SDL_PIXELFORMAT_ABGR8888,
      SDL_TEXTUREACCESS_STREAMING,
      vga.h_active_pixels,
      vga.v_active_lines);

  Verilated::commandArgs(argc, argv);
  TOP_MODULE *top = new TOP_MODULE;

  bool quit = false;
  bool initial_reset = true;
  int hnum = 0;
  int vnum = 0;
  int frame = 0;
  int last_update_ticks = 0;
  while (!quit && !Verilated::gotFinish()) {
    int last_ticks = SDL_GetTicks();
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        quit = true;
      } else if (e.type == SDL_KEYDOWN) {
        switch (e.key.keysym.sym) {
          case SDLK_ESCAPE:
          case SDLK_q:
            quit = true;
            break;
          case SDLK_f:
            fullscreen = fullscreen ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP;
            SDL_SetWindowFullscreen(w, fullscreen);
            break;
          case SDLK_p:
            polarity = !polarity;
            break;
          case SDLK_s:
            slow = !slow;
            break;
          default:
            break;
        }
      }
    }

    auto k = SDL_GetKeyboardState(NULL);
    bool reset_active = initial_reset || k[SDL_SCANCODE_R];
    uint8_t ui_in = 0;
    ui_in |= k[SDL_SCANCODE_0] << 0;
    ui_in |= k[SDL_SCANCODE_1] << 1;
    ui_in |= k[SDL_SCANCODE_2] << 2;
    ui_in |= k[SDL_SCANCODE_3] << 3;
    ui_in |= k[SDL_SCANCODE_4] << 4;
    ui_in |= k[SDL_SCANCODE_5] << 5;
    ui_in |= k[SDL_SCANCODE_6] << 6;
    ui_in |= k[SDL_SCANCODE_7] << 7;

    for (uint64_t cycle = 0; cycle < vga.frame_cycles(); ++cycle) {
      VGApinout_t uo_out = tick_pixel(
          top, dut_clocks_per_pixel, sample_clock, reset_active, ui_in);

      if ((uo_out.hsync == vga.h_sync_pol) ^ polarity &&
          (uo_out.vsync == vga.v_sync_pol) ^ polarity) {
        hnum = -vga.h_back_porch;
        vnum = -vga.v_back_porch;
      }

      if ((hnum >= 0) && (hnum < vga.h_active_pixels) &&
          (vnum >= 0) && (vnum < vga.v_active_lines)) {
        uint8_t rr = 85 * (uo_out.r1 << 1 | uo_out.r0);
        uint8_t gg = 85 * (uo_out.g1 << 1 | uo_out.g0);
        uint8_t bb = 85 * (uo_out.b1 << 1 | uo_out.b0);
        ABGR8888_t rgb = {.r = rr, .g = gg, .b = bb};
        fb[vnum * vga.h_active_pixels + hnum] = rgb;
      }

      hnum++;
      if (hnum >= vga.h_active_pixels + vga.h_front_porch + vga.h_sync_pulse) {
        hnum = -vga.h_back_porch;
        vnum++;
      }
    }
    initial_reset = false;

    SDL_RenderClear(r);
    SDL_UpdateTexture(
        t, NULL, fb.data(), vga.h_active_pixels * sizeof(ABGR8888_t));
    SDL_RenderCopy(r, t, NULL, NULL);
    SDL_RenderPresent(r);

    int ticks = SDL_GetTicks();
    if (ticks - last_update_ticks > 500) {
      last_update_ticks = ticks;
      std::string fps =
          "Tiny Tapeout VGA (" + std::to_string((int)1000.0 / (ticks - last_ticks)) +
          " FPS, " + std::to_string(dut_clocks_per_pixel) + "x DUT clock)";
      SDL_SetWindowTitle(w, fps.c_str());
    }
    if (gif) {
      GifWriteFrame(
          &g, (uint8_t *)fb.data(), vga.h_active_pixels, vga.v_active_lines, delay);
      if (++frame == gif_frames) {
        quit = true;
      }
    }
    if (slow) {
      SDL_Delay(250);
    }
  }

  if (gif) {
    GifEnd(&g);
  }

  top->final();
  delete top;

  SDL_DestroyRenderer(r);
  SDL_DestroyWindow(w);
  SDL_Quit();
}
