# FPGA Real-Time Task Scheduler

A Verilog LED task scheduler implemented on the DE10-Lite FPGA. It selects
LED patterns using a seconds timer and provides SOS and warning priority
overrides.

## Design

Uses DE10-Lite's 50 MHz clock. A divider creates a
one-second enable for the timer; slower timing enables control the LED
patterns. All sequential logic uses the same clock.

The top-level scheduler selects tasks by decoding the seconds count rather
than using one overall FSM. Task modules store LED position and direction,
and the SOS pattern uses step and count registers.

## Task Schedule and Overrides

- **Task 2:** All LEDs turn on at every 10 sec interval.
- **Task 3:** A running light moves from LED0 toward LED9.
- **Task 4:** A light moves between LED9 and LED0, reverse Task 3.
- **SOS (SW[0]):** Overrides the LED output and displays “SOS morse code.”
- **Warning (SW[1]):** Overrides the scheduled LED task with a warning
  pattern.

The output priority is SOS, then warning, then the scheduled task. During
either override, the seconds timer and running-light state pause.

## Challenge

A challenge I encountered was making an interrupted task resume from the
point it had reached. I addressed this by holding the task state during
overrides: Task 3 holds its position and timing counter, while Task 4 holds
its position, direction, and timing counter. The timer also pauses, so the
scheduled task resumes from its previous point after the override.

## Hardware Demonstration and Verification

I implemented the design on the DE10-Lite and recorded it running on the
device: [demo](https://youtu.be/HVqbHCKJYyo).

I have not yet ran a testbench.

## Notes
Quartus pin-assignment file is not
included.
