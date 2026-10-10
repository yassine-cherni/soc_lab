# 6. Notes for the VHDL lab

These belong to the design stage and do not affect installation.

* The original handout targets ISE 12.3 and a 50 MHz Spartan-3E design. The ZC702's PL clock is not 50 MHz and may be a differential input. Read the clock frequency, pins, and I/O standard in [UG850](https://docs.amd.com/v/u/en-US/ug850-zc702-eval-bd) before designing clock generation, and do not copy pin numbers from other boards.
* Reset and the motor-controller outputs (`Mav`, `Mar`, `Tg`, `Td`) need valid XDC constraints. User LEDs and push buttons are useful for early testing, but must not drive motors directly.
* ISE project settings do not transfer to Vivado. Recreate the project and constraints, then add the VHDL sources.
* Do physical programming and JTAG verification only after the software install and device-part check succeed.

Previous: [ZC702 hardware access](05-zc702-hardware.md)
