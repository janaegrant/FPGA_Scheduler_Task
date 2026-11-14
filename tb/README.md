
# FPGA Real-Time Task Scheduler - Testbench Verification

## Overview

This directory contains the Verilog testbenches developed to verify the FPGA Real-Time Task Scheduler.

Verification was performed using **Siemens Questa Altera Starter FPGA Edition 2025.2 (ModelSim/Questa)**.

The verification process consists of three approaches:

1. **Functional Verification** - Checks whether the scheduler produces the correct outputs.
2. **Waveform Verification** - Examines interrupt handling and task state preservation.
3. **Timing Verification** - Measures clock-divider intervals using the simulated 50 MHz clock.

## 1. Overall Test Results

| Testbench | Purpose | Result |
|---|---|---|
| `tester.v` | Automated functional verification | 228 checks passed, 0 failures |
| `Scheduler_wave.v` | Visual verification of SOS interruption and task resumption | Expected waveform observed |
| `scheduler_timing.v` | Real-time clock-divider verification | 1 Hz and 4 Hz passed |

These three testbenches complement each other. Functional testing verifies output correctness, waveform analysis demonstrates signal behaviour during interruptions, and timing verification checks whether the hardware operates at the intended frequency.

---

## 2. Functional Verification - `tester.v`

### Objective

Verify that the scheduler correctly executes scheduled tasks, handles interrupts, preserves task states, and responds to reset conditions.

The testbench uses automated comparisons between expected and actual outputs.

### Test Coverage

The functional testbench contains 13 main verification categories.

| # | Test | Why We Tested It | How We Tested It |
|---|---|---|---|
| 1 | Timer counting and rollover | Ensure the 60-second scheduler repeats correctly | Check transitions from 58 → 59 → 0 → 1 |
| 2 | Task selection boundaries | Verify tasks activate at the correct seconds | Test immediately before, at, and after task boundaries |
| 3 | Task 2 LED activation | Verify scheduled LED activation | Check LED outputs at 10, 20, 30, 40, and 50 seconds |
| 4 | Task 3 moving LED | Verify sequential movement | Check LED0 → LED9 → LED0 |
| 5 | Task 4 bouncing LED | Verify bidirectional movement | Check LED9 → LED0 → LED9 |
| 6 | Warning interrupt | Verify Warning overrides normal tasks | Activate SW1 and inspect LED output |
| 7 | SOS priority | Verify SOS has higher priority than Warning | Activate SW0 and SW1 simultaneously |
| 8 | SOS Morse sequence | Verify SOS output sequence | Compare expected and actual ON/OFF phases |
| 9 | Task 3 pause/resume | Verify task state preservation | Interrupt Task 3 and check its saved position |
| 10 | Task 4 pause/resume | Verify position and direction preservation | Interrupt Task 4 and check its restored state |
| 11 | Repeated SOS messages | Verify continuous SOS operation | Simulate multiple SOS sequences |
| 12 | Interrupt transitions | Verify nested interrupt priority | Test Task 4 → Warning → SOS → Warning → Task 4 |
| 13 | Reset verification | Verify recovery to initial conditions | Apply reset during tasks and interrupts |

### Testing Methodology

The functional testbench uses directed stimulus and automated assertions to compare the scheduler's actual behaviour against expected results.

Internal timing signals are accelerated during simulation to avoid waiting for full real-time intervals.

The testbench checks:

- Correct timer operation and rollover.
- Task activation at scheduled intervals.
- LED movement and blinking patterns.
- SOS and Warning interrupt priority.
- Task state preservation during interruptions.
- Correct reset behaviour.

### Results

**228 functional checks passed, with 0 failures.**

The testbench successfully verified the scheduler's functional behaviour across the tested operating conditions.

---

## 3. Waveform Verification - `Scheduler_wave.v`

### Objective

Visually verify that Task 3 preserves its internal position when interrupted by SOS and resumes correctly after the interrupt ends.

### Test Procedure

1. Reset the scheduler.
2. Initialize Task 3 at LED0.
3. Advance Task 3 to LED1 and LED2.
4. Activate SOS using `SW[0]`.
5. Generate SOS phases while observing the internal Task 3 position.
6. Deactivate SOS.
7. Verify that Task 3 resumes from LED2.
8. Advance Task 3 to LED3.

### Signals Observed

| Signal | Description |
|---|---|
| `SW` | Interrupt switches |
| `dut.t3.pos` | Task 3 LED position |
| `dut.sos_step` | Current SOS sequence step |
| `dut.sos_led` | SOS LED output state |
| `LEDR` | Actual FPGA LED outputs |

### Expected Sequence

```text
Task 3: LED0 → LED1 → LED2
                         |
                         v
                    SOS Activated
                         |
                    Task 3 Paused
                    Position = LED2
                         |
                         v
                    SOS Deactivated
                         |
                         v
Task 3:              LED2 → LED3
```


### Waveform Verification Results

The following waveform demonstrates Task 3 being interrupted
by SOS and resuming from its saved position.

![Task 3 SOS Interrupt Waveform](Screenshot%202026-11-13%20200253.png)

### Results

The observed waveform demonstrated that:

- Task 3 advanced normally before SOS activation.
- Task 3's position remained unchanged during SOS.
- SOS controlled the LED outputs while active.
- Task 3 resumed from its saved position after SOS ended.

**Result: Expected waveform behaviour observed.**


The observed waveform demonstrated that:

- Task 3 advanced normally before SOS activation.
- Task 3's position remained unchanged during SOS.
- SOS controlled the LED outputs while active.
- Task 3 resumed from its saved position after SOS ended.

**Result: Expected waveform behaviour observed.**

---

## 4. Real-Time Timing Verification - `scheduler_timing.v`

### Objective

Verify the accuracy of the scheduler's clock dividers using a simulated 50 MHz FPGA input clock.

Unlike the accelerated functional tests, this testbench measures timing using the actual simulated clock cycles.

### Clock Configuration

| Parameter | Value |
|---|---|
| Input clock frequency | 50 MHz |
| Clock period | 20 ns |
| Scheduler tick frequency | 1 Hz |
| SOS tick frequency | 4 Hz |
| Expected Warning LED transition interval | 500 ms |

### Timing Results

| Signal | Expected Interval | Measured Interval | Status |
|---|---|---|---|
| 1 Hz scheduler tick | 1,000,000,000 ns | 1,000,000,000 ns | PASS |
| 4 Hz SOS tick | 250,000,000 ns | 250,000,000 ns | PASS |

### Timing Analysis

The 1 Hz scheduler tick and 4 Hz SOS tick were verified against their expected intervals.

The Warning LED transition exhibited a difference of 20 ns, equivalent to one 50 MHz clock cycle.

This discrepancy is consistent with an off-by-one counter terminal condition.

The Warning timing check remains unresolved in the recorded test results and requires further verification.

### Results

- **1 Hz clock divider:** PASS
- **4 Hz clock divider:** PASS
- **Warning LED timing:** Discrepancy identified

---

## 5. Tools and Technologies

| Tool / Technology | Purpose |
|---|---|
| Verilog HDL | RTL design and testbench development |
| Siemens Questa Altera Starter FPGA Edition 2025.2 | Simulation and waveform analysis |
| Intel Quartus Prime | FPGA design compilation |
| Terasic DE10-Lite | Target FPGA development board |
| 50 MHz clock | Real-time timing verification |

---

## 6. Running the Testbenches

The testbenches can be compiled and executed using Questa.

The following commands assume the scheduler design is stored at `rtl/Scheduler.v` and the testbenches are in `tb/`.

### Compile the Design and Testbenches

```tcl
vlib work
vlog rtl/Scheduler.v
vlog tb/tester.v
vlog tb/Scheduler_wave.v
vlog tb/scheduler_timing.v
```

### Run Functional Verification

```tcl
vsim -voptargs=+acc work.tb_scheduler
run -all
```

### Run Waveform Verification

```tcl
vsim -voptargs=+acc work.tb_scheduler_wave
view wave
add wave -r sim:/tb_scheduler_wave/*
run -all
wave zoom full
```

### Run Timing Verification

```tcl
vsim work.tb_scheduler_timing
run -all
```

**Note:** The timing simulation can take considerably longer than the functional tests because it simulates the full 50 MHz clock.


---


For the complete FPGA project, see the [main repository](../README.md).
