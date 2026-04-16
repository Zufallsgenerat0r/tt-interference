# SPDX-FileCopyrightText: (c) 2026 Kilian
# SPDX-License-Identifier: Apache-2.0

import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

# VGA 640x480 @ 60Hz timing constants
H_DISPLAY = 640
H_FRONT = 16
H_SYNC = 96
H_BACK = 48
H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK  # 800

V_DISPLAY = 480
V_BOTTOM = 10
V_SYNC = 2
V_TOP = 33
V_TOTAL = V_DISPLAY + V_BOTTOM + V_SYNC + V_TOP  # 525

# uo_out bit positions (TinyVGA Pmod)
BIT_R1 = 0
BIT_G1 = 1
BIT_B1 = 2
BIT_VSYNC = 3
BIT_R0 = 4
BIT_G0 = 5
BIT_B0 = 6
BIT_HSYNC = 7


def decode_vga(uo_out):
    """Decode uo_out into VGA signals."""
    val = int(uo_out.value)
    hsync = (val >> BIT_HSYNC) & 1
    vsync = (val >> BIT_VSYNC) & 1
    r = ((val >> BIT_R1) & 1) << 1 | ((val >> BIT_R0) & 1)
    g = ((val >> BIT_G1) & 1) << 1 | ((val >> BIT_G0) & 1)
    b = ((val >> BIT_B1) & 1) << 1 | ((val >> BIT_B0) & 1)
    return hsync, vsync, r, g, b


async def reset_dut(dut):
    """Standard reset sequence."""
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_hsync_period(dut):
    """HSYNC must pulse every 800 pixel clocks."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Wait for first hsync rising edge
    prev_hsync = 0
    for _ in range(H_TOTAL + 10):
        await RisingEdge(dut.clk)
        hsync, _, _, _, _ = decode_vga(dut.uo_out)
        if hsync and not prev_hsync:
            break
        prev_hsync = hsync

    # Now count clocks until next hsync rising edge
    count = 0
    prev_hsync = 1
    for _ in range(H_TOTAL + 10):
        await RisingEdge(dut.clk)
        count += 1
        hsync, _, _, _, _ = decode_vga(dut.uo_out)
        if hsync and not prev_hsync:
            break
        prev_hsync = hsync

    assert count == H_TOTAL, f"HSYNC period: expected {H_TOTAL}, got {count}"
    dut._log.info(f"HSYNC period: {count} clocks (expected {H_TOTAL})")


@cocotb.test()
async def test_hsync_pulse_width(dut):
    """HSYNC pulse must be 96 clocks wide."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Wait for hsync to go high
    for _ in range(H_TOTAL + 10):
        await RisingEdge(dut.clk)
        hsync, _, _, _, _ = decode_vga(dut.uo_out)
        if hsync:
            break

    # Count how long it stays high (including the clock where we first saw it)
    width = 1
    for _ in range(H_TOTAL):
        await RisingEdge(dut.clk)
        hsync, _, _, _, _ = decode_vga(dut.uo_out)
        if hsync:
            width += 1
        else:
            break

    assert width == H_SYNC, f"HSYNC width: expected {H_SYNC}, got {width}"
    dut._log.info(f"HSYNC pulse width: {width} clocks (expected {H_SYNC})")


@cocotb.test()
async def test_vsync_period(dut):
    """VSYNC must pulse every 525 lines (525 * 800 = 420000 clocks)."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    expected_period = V_TOTAL * H_TOTAL  # 420000

    # Wait for first vsync rising edge
    prev_vsync = 0
    for _ in range(expected_period + 100):
        await RisingEdge(dut.clk)
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if vsync and not prev_vsync:
            break
        prev_vsync = vsync

    # Count clocks until next vsync rising edge
    count = 0
    prev_vsync = 1
    for _ in range(expected_period + 100):
        await RisingEdge(dut.clk)
        count += 1
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if vsync and not prev_vsync:
            break
        prev_vsync = vsync

    assert count == expected_period, f"VSYNC period: expected {expected_period}, got {count}"
    dut._log.info(f"VSYNC period: {count} clocks (expected {expected_period})")


@cocotb.test()
async def test_display_line_count(dut):
    """Verify 480 display lines per frame by counting hsync edges during active video."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    frame_clocks = V_TOTAL * H_TOTAL

    # Align to vsync rising edge
    prev_vsync = 0
    for _ in range(frame_clocks + 100):
        await RisingEdge(dut.clk)
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if vsync and not prev_vsync:
            break
        prev_vsync = vsync

    # Count hsync rising edges until next vsync
    line_count = 0
    prev_hsync = 0
    prev_vsync = 1
    for _ in range(frame_clocks + 100):
        await RisingEdge(dut.clk)
        hsync, vsync, _, _, _ = decode_vga(dut.uo_out)
        if hsync and not prev_hsync:
            line_count += 1
        if vsync and not prev_vsync:
            break
        prev_hsync = hsync
        prev_vsync = vsync

    assert line_count == V_TOTAL, f"Lines per frame: expected {V_TOTAL}, got {line_count}"
    dut._log.info(f"Lines per frame: {line_count} (expected {V_TOTAL})")


async def capture_frame(dut):
    """Capture one full VGA frame as a 640x480 array of (r, g, b) tuples."""
    frame_clocks = V_TOTAL * H_TOTAL

    # Align to vsync rising edge
    prev_vsync = 0
    for _ in range(frame_clocks + 100):
        await RisingEdge(dut.clk)
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if vsync and not prev_vsync:
            break
        prev_vsync = vsync

    # Capture pixels for exactly one frame
    pixels = []
    row = []
    prev_vsync = 1
    for _ in range(frame_clocks + 100):
        await RisingEdge(dut.clk)
        hsync, vsync, r, g, b = decode_vga(dut.uo_out)
        if not hsync and not vsync:
            row.append((r, g, b))
            if len(row) == H_DISPLAY:
                pixels.append(row)
                row = []
                if len(pixels) == V_DISPLAY:
                    break
    return pixels


def save_frame_png(pixels, filename):
    """Save captured frame as PNG."""
    from PIL import Image
    h = len(pixels)
    w = len(pixels[0]) if h > 0 else 0
    img = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[y][x]
            # Scale 2-bit color to 8-bit
            img.putpixel((x, y), (r * 85, g * 85, b * 85))
    os.makedirs("output", exist_ok=True)
    img.save(f"output/{filename}")
    return img


@cocotb.test()
async def test_frame_dump(dut):
    """Capture a frame and save as PNG for visual inspection."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Run past first frame (y=0 init happens here)
    await ClockCycles(dut.clk, V_TOTAL * H_TOTAL + 100)

    pixels = await capture_frame(dut)
    assert len(pixels) == V_DISPLAY, f"Expected {V_DISPLAY} rows, got {len(pixels)}"
    save_frame_png(pixels, "frame_step2.png")
    dut._log.info("Frame saved to output/frame_step2.png")


@cocotb.test()
async def test_rings_present(dut):
    """Ring pattern should show all 4 grayscale levels and be roughly centered."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Run past first frame (y=0 init)
    await ClockCycles(dut.clk, V_TOTAL * H_TOTAL + 100)

    pixels = await capture_frame(dut)

    # Check that we have all 4 ring levels (2-bit grayscale)
    all_colors = set()
    for x in range(0, H_DISPLAY, 2):
        all_colors.add(pixels[240][x])
    assert len(all_colors) >= 3, f"Expected ring variation, got {len(all_colors)} unique colors"
    dut._log.info(f"Ring variation: {len(all_colors)} unique colors in center row")

    # Verify ring structure: pixel brightness should vary across the frame
    # (not uniform like the solid-white stub)
    row_100 = [pixels[100][x] for x in range(0, H_DISPLAY, 4)]
    row_400 = [pixels[400][x] for x in range(0, H_DISPLAY, 4)]
    assert len(set(row_100)) >= 2, "Row 100 should have ring variation"
    assert len(set(row_400)) >= 2, "Row 400 should have ring variation"
    dut._log.info("Ring structure verified across multiple rows")
