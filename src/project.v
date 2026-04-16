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

  wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};

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

  // --- Source A position ---
  wire [4:0] tri_ax = frame_counter[8]  ? ~frame_counter[7:3] : frame_counter[7:3];
  wire [4:0] tri_ay = frame_counter[9]  ? ~frame_counter[8:4] : frame_counter[8:4];
  wire signed [9:0] offset_ax = {5'b0, tri_ax} - 10'sd16;
  wire signed [9:0] offset_ay = {5'b0, tri_ay} - 10'sd16;

  // --- Source B position (inverted triangle = opposite phase, different periods) ---
  wire [4:0] tri_bx = frame_counter[9]  ? frame_counter[8:4] : ~frame_counter[8:4];
  wire [4:0] tri_by = frame_counter[7]  ? frame_counter[6:2] : ~frame_counter[6:2];
  wire signed [9:0] offset_bx = {5'b0, tri_bx} - 10'sd16;
  wire signed [9:0] offset_by = {5'b0, tri_by} - 10'sd16;

  // --- Source centers and pixel distances ---
  wire signed [9:0] center_ax = 10'sd320 + offset_ax;
  wire signed [9:0] center_ay = 10'sd240 + offset_ay;
  wire signed [9:0] p_ax = x - center_ax;
  wire signed [9:0] p_ay = y - center_ay;

  wire signed [9:0] center_bx = 10'sd320 + offset_bx;
  wire signed [9:0] center_by = 10'sd240 + offset_by;
  wire signed [9:0] p_bx = x - center_bx;
  wire signed [9:0] p_by = y - center_by;

  // --- Distance-squared accumulators (two sources) ---
  reg signed [17:0] r1a, r1b;
  reg signed [18:0] r2a, r2b;
  wire signed [19:0] ra = 2*(r1a - center_ay*2) + r2a - center_ax*2 + 2;
  wire signed [19:0] rb = 2*(r1b - center_by*2) + r2b - center_bx*2 + 2;

  always @(posedge clk) begin
    if (~rst_n) begin
      r1a <= 0; r2a <= 0;
      r1b <= 0; r2b <= 0;
    end else begin
      if (vsync) begin
        r1a <= 0; r2a <= 0;
        r1b <= 0; r2b <= 0;
      end

      if (display_on & y == 0) begin
        // Both sources init y-squared during first scanline
        if (x < center_ay) r1a <= r1a + center_ay;
        if (x < center_by) r1b <= r1b + center_by;
      end else if (x == 640) begin
        r2a <= 320*320;
        r2b <= 320*320;
      end else if (x > 640) begin
        // Source A hblank offset
        if (offset_ax > 0 && x - 10'd641 < {5'd0, offset_ax[4:0]})
          r2a <= r2a + 10'sd640 + offset_ax;
        else if (offset_ax < 0 && x - 10'd641 < {5'd0, ~offset_ax[4:0] + 5'd1})
          r2a <= r2a - (10'sd640 + offset_ax);
        // Source B hblank offset (independent)
        if (offset_bx > 0 && x - 10'd641 < {5'd0, offset_bx[4:0]})
          r2b <= r2b + 10'sd640 + offset_bx;
        else if (offset_bx < 0 && x - 10'd641 < {5'd0, ~offset_bx[4:0] + 5'd1})
          r2b <= r2b - (10'sd640 + offset_bx);
      end else if (display_on & x == 0) begin
        r1a <= r1a + 2*p_ay + 1;
        r1b <= r1b + 2*p_by + 1;
      end else if (display_on) begin
        r2a <= r2a + 2*p_ax + 1;
        r2b <= r2b + 2*p_bx + 1;
      end
    end
  end

  // --- Interference: chromatic phase offset ---
  // Each RGB channel XORs different bit pairs from the distance metrics,
  // creating rainbow-like color separation in the interference pattern.
  // ui_in[1:0] selects palette variant.
  wire [1:0] palette = ui_in[1:0];

  wire [1:0] R_ring = ra[9:8]   ^ rb[9:8];
  wire [1:0] G_ring = ra[10:9]  ^ rb[10:9];
  wire [1:0] B_ring = ra[11:10] ^ rb[11:10];

  // Palette variations via simple bit manipulation
  wire [1:0] R = display_on ? (palette[0] ? G_ring : R_ring) : 2'b00;
  wire [1:0] G = display_on ? (palette[1] ? B_ring : G_ring) : 2'b00;
  wire [1:0] B = display_on ? (palette[0] ^ palette[1] ? R_ring : B_ring) : 2'b00;

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
