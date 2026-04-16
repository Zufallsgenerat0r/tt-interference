/*
 * Copyright (c) 2026 Kilian
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_kilian_interference (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock 25.175 MHz
    input  wire       rst_n     // reset_n - low to reset
);

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, ui_in, uio_in, 1'b0};

  wire hsync, vsync, display_on;
  wire [9:0] x, y;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(x),
    .vpos(y)
  );

  wire [1:0] R = display_on ? 2'b11 : 2'b00;
  wire [1:0] G = display_on ? 2'b11 : 2'b00;
  wire [1:0] B = display_on ? 2'b11 : 2'b00;

  // TinyVGA Pmod: {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule


// VGA 640x480 @ 60Hz sync generator
// Proven in silicon (tt08-vga-drop by ReJ/Renaldas Zioma)
module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);
    input clk;
    input reset;
    output reg hsync, vsync;
    output display_on;
    output reg [9:0] hpos;
    output reg [9:0] vpos;

    parameter H_DISPLAY       = 640;
    parameter H_BACK          =  48;
    parameter H_FRONT         =  16;
    parameter H_SYNC          =  96;
    parameter V_DISPLAY       = 480;
    parameter V_TOP           =  33;
    parameter V_BOTTOM        =  10;
    parameter V_SYNC          =   2;

    parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
    parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
    parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
    parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

    wire hmaxxed = (hpos == H_MAX) || reset;
    wire vmaxxed = (vpos == V_MAX) || reset;

    always @(posedge clk)
    begin
      hsync <= (hpos>=H_SYNC_START && hpos<=H_SYNC_END);
      if(hmaxxed)
        hpos <= 0;
      else
        hpos <= hpos + 1;
    end

    always @(posedge clk)
    begin
      vsync <= (vpos>=V_SYNC_START && vpos<=V_SYNC_END);
      if(hmaxxed)
        if (vmaxxed)
          vpos <= 0;
        else
          vpos <= vpos + 1;
    end

    assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);
endmodule
