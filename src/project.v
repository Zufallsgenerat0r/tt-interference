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

  // --- Frame counter (increments once per frame on vsync rising edge) ---
  reg [11:0] frame_counter;
  reg vsync_prev;
  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 0;
      vsync_prev <= 0;
    end else begin
      vsync_prev <= vsync;
      if (vsync && !vsync_prev)
        frame_counter <= frame_counter + 1;
    end
  end

  // --- Source position via triangle waves ---
  // ±16 pixels range, smooth drift.
  // tri_x: 5-bit, period 512 frames (~8.5s), steps every 8 frames
  // tri_y: 5-bit, period 1024 frames (~17s), steps every 16 frames
  wire [4:0] tri_x = frame_counter[8] ? ~frame_counter[7:3] : frame_counter[7:3];
  wire [4:0] tri_y = frame_counter[9] ? ~frame_counter[8:4] : frame_counter[8:4];

  // Map triangle (0..31) to screen offset (-16..+15) from center
  wire signed [9:0] offset_x = {5'b0, tri_x} - 10'sd16;
  wire signed [9:0] offset_y = {5'b0, tri_y} - 10'sd16;

  // --- Distance-squared accumulator (single moving source) ---
  // Adopted from tt08-vga-drop (proven in silicon).
  wire signed [9:0] center_x = 10'sd320 + offset_x;
  wire signed [9:0] center_y = 10'sd240 + offset_y;
  wire signed [9:0] p_x = x - center_x;
  wire signed [9:0] p_y = y - center_y;

  reg signed [17:0] r1;
  reg signed [18:0] r2;
  wire signed [19:0] r = 2*(r1 - center_y*2) + r2 - center_x*2 + 2;

  always @(posedge clk) begin
    if (~rst_n) begin
      r1 <= 0;
      r2 <= 0;
    end else begin
      if (vsync) begin
        r1 <= 0;
        r2 <= 0;
      end

      if (display_on & y == 0) begin
        // Compute center_y^2 by repeated addition (no multiplier)
        if (x < center_y)
          r1 <= r1 + center_y;
      end else if (x == 640) begin
        // (320+ox)^2 = 320^2 + (640+ox)*ox
        // Start with 320^2, accumulate remainder during hblank
        r2 <= 320*320;
      end else if (x > 640) begin
        // Accumulate (640+offset_x)*|offset_x| by repeated addition
        // Add when offset_x > 0, subtract when offset_x < 0
        if (offset_x > 0 && x - 10'd641 < {5'd0, offset_x[4:0]})
          r2 <= r2 + 10'sd640 + offset_x;
        else if (offset_x < 0 && x - 10'd641 < {5'd0, ~offset_x[4:0] + 5'd1})
          r2 <= r2 - (10'sd640 + offset_x);
      end else if (display_on & x == 0) begin
        r1 <= r1 + 2*p_y + 1;
      end else if (display_on) begin
        r2 <= r2 + 2*p_x + 1;
      end
    end
  end

  // Extract ring pattern from distance metric
  // K=8: ring band changes every 256 in r-value
  wire [1:0] ring = r[9:8];

  wire [1:0] R = display_on ? ring : 2'b00;
  wire [1:0] G = display_on ? ring : 2'b00;
  wire [1:0] B = display_on ? ring : 2'b00;

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
