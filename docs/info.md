## How it works

Wave Lattice is a port of Taylor Troesh's browser sketch at
<https://taylor.town/waves> (itself inspired by Zach Lieberman) to pure
silicon logic. A 40×30 grid of dots is drawn against a black background
over VGA. Two radial wave sources interfere across the screen; where
each dot would land is displaced by that interference field, so the
regular lattice warps into compression rings around the sources.

A single virtual "pointer" slowly traces a Lissajous figure (3:5
frequency ratio between the x and y axes) within a ±64-pixel box
around screen centre, completing one full woven cycle every ~17
seconds. Source A sits at the pointer, source B at its point-mirror
`(640-x, 480-y)` — directly analogous to the JS original where the
second source is the mirror of the mouse position.

The interference surface is computed per-pixel by the same
distance-squared accumulator trick used in `tt-interference` (no
multipliers on the hot path, just adders and an XOR-like phase
extraction). Displacement direction comes from the sign of the
already-signed pixel-to-centre delta; displacement magnitude comes from
the phase bits of the accumulator, with one of those bits acting as a
sign that flips across each ridge (the silicon equivalent of
`tanh(sharp · sin)` in the JS original — dots *compress* onto ridges
and *rarefy* in troughs).

There is no frame buffer, no line buffer, and no per-dot state: the
only storage is the two 14-bit accumulators, a 12-bit lattice-anchor
latch, and the counters needed for the Lissajous trajectory. Dots
don't carry inertia across frames; the JS version's per-dot
damped-spring smoothing is the one visible omission.

## How to test

Connect a TinyVGA Pmod to the output pins. The design expects a
25.175 MHz clock. After reset you should see a field of white dots on
black, warping around the two source centres as the pointer weaves a
slow Lissajous figure through the centre of the screen.

Use the input DIP switches to adjust parameters:

- `ui_in[1:0]`: palette (00=white, 01=cyan, 10=magenta, 11=yellow)
- `ui_in[2]`: freeze the pointer at its current position
- `ui_in[3]`: halve the trajectory speed

## External hardware

TinyVGA Pmod (VGA output)
