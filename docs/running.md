# Running Vivado and Vitis HLS

Daily use after the install is verified. Part for every project: `xc7z020clg484-1` (ZC702). Not `clg400`, not any `xa7...` part.

## 1. Start the container (host)

```bash
cd "$HOME/Desktop/soc_lab"
./docker/run.sh
```

You land in `/work` with Vivado, Vitis, and Vitis HLS on `PATH`. For a second shell use `docker exec -it vivado bash`. Never start `run.sh` twice.

Check the GUI path once per session:

```bash
xdpyinfo | head -n 3
```

## 2. Always work from `/work/build`

Vivado writes `vivado.log`, `vivado.jou`, and `.Xil/` into the directory it starts from. `/work/build` is ignored by Git, so the repository root stays clean.

```bash
mkdir -p /work/build/vivado /work/build/hls
cd /work/build
```

## 3. Vivado

GUI (the `&` returns the prompt, close the window to end it):

```bash
vivado &
```

Optional, no log or journal files at all:

```bash
vivado -nolog -nojournal &
```

Batch (no GUI):

```bash
vivado -mode batch -source /work/scripts/build.tcl
```

Batch straight from the host, one command. The `bash -ic` is required because the environment loads only in interactive shells:

```bash
./docker/run.sh bash -ic 'cd /work/build && vivado -mode batch -source /work/scripts/build.tcl'
```

Vivado renames a previous log to `vivado_<pid>.backup.log` when a new session starts. These are safe to delete.

### New project settings

| Wizard step | Choose |
|---|---|
| Project name / location | `robot_controller` in `/work/build/vivado` (keep "Create project subdirectory") |
| Project type | RTL Project |
| Default part | Parts tab, `xc7z020clg484-1` (484 pins, 200 IOBs) |

Or pick **Zynq-7000 ZC702 Evaluation Platform** on the Boards tab. The summary page must show Package `clg484`, Speed Grade `-1`.

After creating it:

- Add sources from `/work/rtl`, XDC from `/work/constraints`, testbenches from `/work/sim`, with **Copy sources into project unticked**.
- Settings > General: Target language and Simulator language = VHDL.
- Export a rebuild script: `write_project_tcl -force /work/scripts/create_project.tcl`

### Minimal `scripts/build.tcl` (non-project flow)

```tcl
set part xc7z020clg484-1
set top  robot_controller
file mkdir /work/build/out
read_vhdl [glob /work/rtl/*.vhd]
read_xdc  [glob /work/constraints/*.xdc]
synth_design -top $top -part $part
opt_design
place_design
route_design
report_timing_summary -file /work/build/out/timing.rpt
write_bitstream -force /work/build/out/$top.bit
```

Remove `read_xdc` until you have constraints. Bitstreams (`*.bit`) are never committed.

## 4. Vitis HLS

HLS runs from the command line. The Vitis IDE and the embedded software flow are not set up here, and `vitis_hls` itself only exists under `bin/unwrapped/lnx64.o`. Use `vitis-run` and `v++`.

```bash
vitis-run --version        # v2026.1
v++ -c --mode hls --help   # compile options
vitis-run --mode hls --help
```

Example config, `/work/hls/hls_config.cfg`:

```ini
part=xc7z020clg484-1

[hls]
flow_target=vivado
package.output.format=ip_catalog
syn.top=your_top_function
syn.file=/work/hls/your_file.cpp
tb.file=/work/hls/your_tb.cpp
clock=10ns
```

Run from `/work/build/hls`:

```bash
cd /work/build/hls
vitis-run --mode hls --csim      --config /work/hls/hls_config.cfg --work_dir hls_run   # C simulation
v++ -c --mode hls                --config /work/hls/hls_config.cfg --work_dir hls_run   # synth + export IP
```

Key names and `vitis-run` flags can change between releases. If one is rejected, check the `--help` output above. Set `clock` from the real PL clock in UG850, not 50 MHz.

The exported IP lands under `hls_run`. In Vivado add it with Settings > IP > Repository, pointing at that folder.

## 5. Quick checks

```bash
vivado -version
vitis-run --version
echo "$XILINXD_LICENSE_FILE"
```

Vivado prints `A valid Vivado Design Suite BASIC license has been detected` on every start. The license expires 10-oct-2027 on this machine.