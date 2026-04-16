# SPDX-FileCopyrightText: (c) 2026 Kilian
# SPDX-License-Identifier: Apache-2.0

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
async def test_active_pixel_count(dut):
    """Exactly 640*480 = 307200 active pixels per frame (non-black during display)."""
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    frame_clocks = V_TOTAL * H_TOTAL  # 420000

    # Wait for vsync rising edge to align to frame start
    prev_vsync = 0
    for _ in range(frame_clocks + 100):
        await RisingEdge(dut.clk)
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if vsync and not prev_vsync:
            break
        prev_vsync = vsync

    # Wait for vsync to end and display to begin
    for _ in range(frame_clocks):
        await RisingEdge(dut.clk)
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if not vsync:
            break

    # Wait for next vsync rising edge = start of a fresh frame
    prev_vsync = 0
    for _ in range(frame_clocks):
        await RisingEdge(dut.clk)
        _, vsync, _, _, _ = decode_vga(dut.uo_out)
        if vsync and not prev_vsync:
            break
        prev_vsync = vsync

    # Now count active pixels for one full frame
    active_count = 0
    prev_vsync = 1
    frame_done = False
    for _ in range(frame_clocks + 100):
        await RisingEdge(dut.clk)
        hsync, vsync, r, g, b = decode_vga(dut.uo_out)
        # Active pixel = any color channel non-zero (design outputs solid color during display)
        if not hsync and not vsync and (r or g or b):
            active_count += 1
        # Detect next vsync rising edge = frame complete
        if vsync and not prev_vsync:
            frame_done = True
            break
        prev_vsync = vsync

    expected = H_DISPLAY * V_DISPLAY  # 307200
    assert frame_done, "Never saw second vsync - frame didn't complete"
    assert active_count == expected, f"Active pixels: expected {expected}, got {active_count}"
    dut._log.info(f"Active pixels per frame: {active_count} (expected {expected})")
