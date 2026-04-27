![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/gl_test/badge.svg)

# Wave Lattice — Interference Dot Lattice for Tiny Tapeout

A 40×30 dot lattice displaced by two interfering wave sources on a Lissajous trajectory — no CPU, no memory, pure logic. VGA output at 640×480 @ 60 Hz.

- [Read the documentation for project](docs/info.md)

## VGA Simulator

This repo includes [`jar/vga_sim`](https://github.com/jar/vga_sim) as a submodule
for fast Verilator/SDL preview of the TinyVGA output.

```bash
git submodule update --init
make -C vga_sim sim
```

The simulator reads `info.yaml`, builds the sources listed under `src`, and runs
the top module. Use `make -C vga_sim gif` to record `vga_sim/output.gif`.
Runtime options include `--polarity` for checking sync polarity.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)
