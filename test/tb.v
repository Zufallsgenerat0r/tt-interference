`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Pass -DDUMP_WAVES at iverilog invocation (or `make waves`) to record a
  // full waveform. Otherwise skip — writing 300k cycles to FST cuts sim speed
  // by ~10×, and most tests don't need it.
  initial begin
`ifdef DUMP_WAVES
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
`endif
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_kilian_interference user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
