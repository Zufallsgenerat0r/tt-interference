![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/gl_test/badge.svg)

# Wave Lattice — Interference Dot Lattice for Tiny Tapeout

A 40×30 dot lattice displaced by two interfering wave sources on a Lissajous trajectory — no CPU, no memory, pure logic. VGA output at 640×480 @ 60 Hz.

- [Read the documentation for project](docs/info.md)

## Disclaimer

This repository has been developed with the help of various large language models (LLMs).

## VGA Simulator

This repo includes [`jar/vga_sim`](https://github.com/jar/vga_sim) as a submodule
and a repo-local wrapper in `sim/` for fast Verilator/SDL preview of the TinyVGA
output. The wrapper derives the DUT clock ratio from `info.yaml`, so this
2x-clock design advances two DUT clocks per VGA pixel.

```bash
git submodule update --init
make -C sim sim
```

The simulator reads `info.yaml`, builds the sources listed under `src`, and runs
the top module. Use `make -C sim gif` to record `sim/output.gif`, or
`make -C sim video` to record a 30-second `sim/output.mp4`. The default
simulator arguments include `--polarity`, matching the raw ASIC sync pins before
the OrangeCrab wrapper inverts them for the TinyVGA Pmod.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)
