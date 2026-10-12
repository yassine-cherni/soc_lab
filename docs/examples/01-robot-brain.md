# Example 1: Programmable robot brain

A small processor in VHDL that runs a tiny program to drive a walking robot. It is the first worked example in this repo: FSM, datapath, and motor controller on the ZC702 (`xc7z020clg484-1`).

Adapted from a university digital systems lab (Ing3 micro-systems course) that targeted ISE 12.3 and a 50 MHz Spartan-3E. This version is rewritten for Vivado 2026.1 and the ZC702. The original handout is not included.

Status: in progress. See the checklist at the end.

## 1. What the robot does

The robot can walk one step forward or back, and turn 90 degrees left or right. It has 4 eight-bit counters so programs can contain loops. Instructions are 16 bits: 6-bit opcode, 2-bit counter number, 8-bit value or address.

| Instruction | Opcode | Effect |
|---|---|---|
| `mav` | `000000` | step forward |
| `mar` | `000001` | step back |
| `tg` | `000010` | turn 90 degrees left |
| `td` | `000011` | turn 90 degrees right |
| `set c, v` | `001000` | counter `c` = `v` |
| `decr c` | `001100` | counter `c` = counter `c` - 1 |
| `bnz c, a` | `010000` | if counter `c` is not 0, jump to instruction `a` |
| halt | `111111` | stop |

Test program (walk a square, 16 steps per side, 4 sides):

```text
0  set 0,4     # counter 0 = 4 sides
1  set 1,16    # counter 1 = 16 steps
2  mav         # one step
3  decr 1
4  bnz 1,2     # repeat until 16 steps done
5  tg          # turn left
6  decr 0
7  bnz 0,1     # next side
```

## 2. Architecture

```text
Clk, Reset
   |
 +-----+  control word   +-----------+
 | FSM |---------------->| Data_Path |
 |     |<----------------|           |
 +-----+  IR[15:10],     +-----------+
    |     Cmp_Neq0
    | Mouvement, Sens, Go, Retard
    v
 +------------------+
 | Motor_Controller |--> Mav, Mar, Tg, Td
 +------------------+
```

| Module | Role |
|---|---|
| `Data_Path` | PC, instruction register, 16-bit ROM, decoder, 4 counters with decrementers, zero detector |
| `FSM_Motor` | Control unit: fetch, decode, one state per instruction, wait for rotation, halt |
| `Motor_Controller` | Turns `Mouvement`, `Sens`, `Go` into `Mav`, `Mar`, `Tg`, `Td`; a divider (`Retard`, `Time_Set`) slows the clock to motor speed |

Datapath control signals: `IR_Load`, `Jmp`, `PC_Load`, `Set_Dec`, `Cmp_Load`. Status back to the FSM: `Cmp_Neq0`.

Motor encoding: `Mouvement` = 1 turn, 0 walk. `Sens` = 1 forward or left, 0 back or right.

## 3. FSM outputs

| State | IR_Load | Jmp | PC_Load | Set_Dec | Cmp_Load | Mouvement | Sens | Go | Retard | Halt |
|---|---|---|---|---|---|---|---|---|---|---|
| start | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| fetch | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| decode | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| mav | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 0 |
| mar | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| tg | 0 | 0 | 1 | 0 | 0 | 1 | 1 | 1 | 1 | 0 |
| td | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1 | 0 |
| set | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| decr | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| bnz | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| halt | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| wait rotation | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |

Check before relying on this table: `mav` has `PC_Load` = 0 while `mar`, `tg`, `td` have 1. If the PC never advances after `mav`, the program stalls. Confirm in simulation and fix the table if it is a typo. Also confirm how `bnz` uses `Jmp` to choose between jump and PC + 1.

## 4. Porting notes for the ZC702

- The ZC702 PL clock is not 50 MHz and may be a differential input. Read UG850 before writing the clock logic.
- `Mav`, `Mar`, `Tg`, `Td` need XDC pins. Use LEDs for first tests. Never drive real motors directly from FPGA pins.
- Motor-speed timing (`Time_Set`) depends on the real clock. Derive the divider from the actual frequency.
- ISE project files do not transfer. Recreate the project in Vivado.

## 5. Files

```text
rtl/ex01_robot_brain/          VHDL sources
sim/ex01_robot_brain/          testbenches
constraints/ex01_robot_brain.xdc
scripts/ex01_robot_brain/create_project.tcl
```

## 6. Build it

Inside the container, from `/work/build`:

```bash
cd /work/build
vivado &
```

New project: name `ex01_robot_brain`, location `/work/build/vivado`, RTL project, part `xc7z020clg484-1`. Add sources from `rtl/ex01_robot_brain` and the XDC without copying them into the project. When it works, export the rebuild script:

```tcl
write_project_tcl -force /work/scripts/ex01_robot_brain/create_project.tcl
```

Batch rebuild:

```bash
./docker/run.sh bash -ic 'cd /work/build && vivado -mode batch -source /work/scripts/ex01_robot_brain/create_project.tcl'
```

## 7. Checklist

- [ ] ROM with the square program
- [ ] `Data_Path` simulates: fetch, set, decr, bnz
- [ ] `FSM_Motor` matches the output table
- [ ] `Motor_Controller` basic version (`Mav`, `Mar`, `Tg`, `Td`)
- [ ] Full testbench: 4 sides of 16 steps, then halt
- [ ] XDC for the ZC702, LEDs first
- [ ] Bitstream and board test
- [ ] Motor controller improved version (stepper signals, `Rom_Mouvement`, `Rom_Rotation`)

## Credit

Based on the Ing3 digital micro-systems lab, "Prototypage d'un cerveau du robot programmable". Design and code in this repo are original work for the Vivado flow.