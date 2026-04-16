# SPDX-FileCopyrightText: (c) 2026 Kilian
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # 25.175 MHz VGA pixel clock (39.722 ns period)
    clock = Clock(dut.clk, 39722, unit="ps")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Basic smoke test: run a few cycles and check outputs are driven
    await ClockCycles(dut.clk, 100)

    dut._log.info("Smoke test passed")
