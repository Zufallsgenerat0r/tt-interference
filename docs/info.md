## How it works

Interference Ripples generates organic water-caustic patterns using multiple orbiting wave sources. At each pixel, the squared distance to each source is computed incrementally (no multiplier needed), and phase bits from the distances are XORed to create interference patterns. Different RGB channels use offset phase bits, creating chromatic separation.

The entire effect is purely algorithmic: every pixel is computed from (x, y, frame_counter) with no CPU, no memory, and no lookup tables.

## How to test

Connect a VGA Pmod to the output pins. The design expects a 25.175 MHz clock. After reset, interference ripple patterns should appear on the VGA display, with wave sources orbiting smoothly.

Use the input DIP switches to adjust parameters:
- `ui_in[1:0]`: palette select (4 color schemes)

## External hardware

TinyVGA Pmod (VGA output)
