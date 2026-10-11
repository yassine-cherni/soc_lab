# Troubleshooting

## Docker and image

**`docker build` fails with 404 on `libtinfo5`**
The pinned package version is no longer available. Update the three `ARG` lines at the top of the Dockerfile with a current version and hashes ([how](03-docker-environment.md#notes-on-the-image)).

**`docker build` fails with `dial tcp ... i/o timeout`**
Docker Hub or the Ubuntu mirrors were unreachable. Check the connection and rebuild.

**Dockerfile changes do not appear**
Rebuild the image. Installed software and the home directory live in persistent volumes, so a rebuild does not remove them.

**Permission denied on `/work`**
Rebuild the image with the host UID:

```bash
docker build --build-arg UID="$(id -u)" -t vivado-base:24.04 docker/
```

**Something I installed or saved is gone after restarting**
The container is discarded on exit. Only `/work`, `/tools/Xilinx`, `/home/vivado`, and `/installer` persist ([details](03-docker-environment.md#what-persists-and-what-does-not)). Add needed packages to the Dockerfile, and save files under `/work`.

**`docker: Error response ... name "/vivado" is already in use`**
A container named `vivado` is still running (for example from a closed terminal). Open a shell in it with `docker exec -it vivado bash`, or stop it with `docker stop vivado` and run `./docker/run.sh` again.

**`vivado: command not found` when passing a command to `run.sh`**
The environment is loaded by interactive shells only. Use `./docker/run.sh bash -ic '<command>'` ([details](03-docker-environment.md#second-terminal-and-batch-commands)).

**`run.sh` says the image was not found**
Build `vivado-base:24.04` first ([build step](03-docker-environment.md#build-the-image)).

## Installer

**"Cannot write to /tools/Xilinx" or a permission error at install**
`/tools/Xilinx` is a host folder (by default `~/xilinx/tools`). Make sure it is owned by your UID: `sudo chown -R "$(id -u):$(id -g)" ~/xilinx`. If you set `XILINX_TOOLS_MOUNT` yourself, fix that directory instead.

**`chmod: Read-only file system`**
Run `chmod +x` on the installer on the host, not inside the container.

**Download stalls, checksum errors, or the installer or container stopped mid-install**
Checksum retries are normal. If it stopped, relaunch the container and rerun the installer; it resumes. If the connection keeps failing, use the offline image route described at the top of [Install Vivado](04-install-vivado.md).

**`installLibs.sh`: `$'\r': command not found`, or a syntax error near `elif`**
The script has Windows line endings. Run `dos2unix` on it, then run it again ([step 4.2](04-install-vivado.md#42-check-required-libraries)).

**`installLibs.sh` not found**
The path can differ from AMD's documentation. Locate it with `find /tools/Xilinx -name installLibs.sh`.

**Installer or Vivado reports a missing library**
Use AMD's `installLibs.sh` procedure and diagnose the actual missing dependency. Do not create `.so.5` to `.so.6` symlinks. Then add the package to the Dockerfile so it persists.

## Vivado and licensing

**Valid license not found**
Confirm the `.lic` file exists inside the container, `XILINXD_LICENSE_FILE` points directly to it, and the host ID matches (use `vlm`, View Host Information). Confirm the license has not expired, since Basic must be renewed yearly, and that it covers the installed release.

**`vlm` or `lmutil` fails to start, or reports a missing LSB loader**
Check that `/lib64/ld-lsb-x86-64.so.3` exists in the container. The Dockerfile creates it; if you are on an older image, rebuild.

**HLS tool not found (`vitis-run`, `v++`, or `vitis_hls`: command not found)**
The Vitis or Vitis HLS `settings64.sh` was not sourced. Find it with `find /tools/Xilinx/2026.1 -maxdepth 2 -name settings64.sh`, add its directory name to the `for` list in `docker/vivado-env.sh`, rebuild the image, and open a new shell ([step 4.9](04-install-vivado.md#49-verify-vitis-hls)).

**HLS reports no valid license**
Check that you ticked **Vitis HLS License** as well as Basic when generating, that both license files are listed in `XILINXD_LICENSE_FILE` if you have two, and that the host ID matches. See [step 4.9](04-install-vivado.md#49-verify-vitis-hls) for the feature check.

**`vivado: command not found`**
`settings64.sh` was not sourced. Check that `/tools/Xilinx/2026.1/Vivado/settings64.sh` exists, then open a new shell.

**GUI is blank, crashes, or does not open**
Verify `DISPLAY` is set, `/tmp/.X11-unix` is mounted, and the `libxcb-*` packages are in the image. Under Wayland, verify XWayland is available and check X server permissions. Try `--ipc=host` only if a shared-memory issue is reported.

**USB devices visible but Vivado cannot access JTAG**
Confirm the cable is in U23 (not J1), SW10 selects USB-JTAG, the cable rules are installed on the host ([hardware guide](05-zc702-hardware.md#52-install-cable-rules-on-the-host)), and USB permissions allow access. Replug the board and restart the container if needed.

**`/tools/Xilinx` is empty after a restart**
The container is probably using a different host folder than the one you installed into. On the host, run `echo "$XILINX_TOOLS_MOUNT"` and `ls ~/xilinx/tools`. If the variable is set in one terminal but not another, `run.sh` falls back to `~/xilinx/tools`. Set the variable in `~/.bashrc` or change the default in `docker/run.sh`. If you installed before moving to host folders, the install is still in the old `vivado-tools` volume: see [Migrating from named volumes](03-docker-environment.md#migrating-from-named-volumes).

## Persistent storage warning

The Vivado install and your license live in `~/xilinx/tools` and `~/xilinx/home` on the host. Deleting a container, rebuilding the image, `docker volume prune`, and `docker system prune` do not touch them. Only deleting those folders does, so do not remove them casually.

Back up `~/xilinx/home` (small, holds the copied license) and keep the license file in `~/installer`. If you ever used the older named volumes `vivado-tools` or `vivado-home`, `docker volume rm` and volume prunes delete them.