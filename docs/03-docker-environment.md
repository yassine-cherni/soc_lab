# 3. Docker environment

The configuration lives in `docker/`:

| File | Purpose |
|---|---|
| [`docker/Dockerfile`](../docker/Dockerfile) | Ubuntu 24.04 image with Vivado dependencies and a `vivado` user |
| [`docker/run.sh`](../docker/run.sh) | Starts the container with X11, USB, volumes, and host networking |
| [`docker/vivado-env.sh`](../docker/vivado-env.sh) | Sources the Vivado, Vitis, and Vitis HLS `settings64.sh` files that exist, and sets `XILINXD_LICENSE_FILE` |

`vivado-env.sh` loads whichever of the Vivado, Vitis, and Vitis HLS settings files exist, so it works before and after the install. Vitis embedded software development (apps on the Zynq PS) is not set up here.

## Build the image

Run on the host from the repository root, initially and whenever the Dockerfile changes:

```bash
cd "$HOME/Desktop/soc_lab"

docker build \
    --build-arg UID="$(id -u)" \
    -t vivado-base:24.04 \
    docker/
```

## Start the container

Run whenever you want to open the Vivado environment:

```bash
cd "$HOME/Desktop/soc_lab"
./docker/run.sh
```

If the script is not executable, run `chmod +x docker/run.sh` once.

The container starts in `/work`, mapped to the host's `soc_lab` repository.

## What persists and what does not

The container runs with `--rm`, so its own filesystem is discarded on exit. Only these paths survive:

| Container path | Backed by | Holds |
|---|---|---|
| `/work` | host repo (bind mount) | HDL sources, scripts, your projects |
| `/tools/Xilinx` | `vivado-tools` volume or host dir | the Vivado install |
| `/home/vivado` | `vivado-home` volume or host dir | license copy, `~/.Xilinx` settings and install config |
| `/installer` | `~/installer` (bind mount) | installer and license source files |

Everything else is lost, including files in `/tmp` and packages installed at runtime with `sudo apt-get`. Save work under `/work`, and put any extra library the tools need into the Dockerfile and rebuild (see [section 4.7](04-install-vivado.md#47-post-install-libraries-if-needed)). Rebuilding the image does not touch the volumes.

## Configuration variables

Set these before running `run.sh`, for example `XILINX_TOOLS_MOUNT=/data/xilinx ./docker/run.sh`.

| Variable | Default | Meaning |
|---|---|---|
| `XILINX_TOOLS_MOUNT` | `vivado-tools` | Volume name, or an absolute host path |
| `VIVADO_HOME_MOUNT` | `vivado-home` | Volume name, or an absolute host path |
| `INSTALLER_DIR` | `~/installer` | Host directory mounted at `/installer` |

A value starting with `/` is treated as a host directory. `run.sh` creates it and warns if it is not owned by your UID, because the container user has your UID and would otherwise be unable to write there. A host directory mounted at `/home/vivado` starts empty, so it does not carry the image's default dotfiles. The shell still loads `vivado-env.sh` through `/etc/bash.bashrc`.

## Notes on the image

* Legacy `libtinfo5` and `libncurses5` are installed as real packages, downloaded over HTTPS and verified against a pinned SHA-256. Never replace them with `.so.6` symlinks: the ABIs differ.
* The pinned versions download from Ubuntu's archive and are checked against SHA-256 hashes. If `docker build` ever fails with a 404 on `libtinfo5`, list the available versions and recompute the hashes:

  ```bash
  curl -fsSL https://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/ \
      | grep -o 'lib\(tinfo5\|ncurses5\)_[^"<]*amd64.deb' | sort -u

  v=<new-version>
  for n in libtinfo5 libncurses5; do
      curl -fsSLO "https://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/${n}_${v}_amd64.deb"
  done
  sha256sum lib*5_${v}_amd64.deb
  ```

  Put the new version and hashes into the three `ARG` lines at the top of the Dockerfile.
* A symlink from `/lib64/ld-lsb-x86-64.so.3` to the real loader is created because `lmutil`, `lmgrd`, and the Vivado License Manager (`vlm`) expect the LSB loader, which Ubuntu 24.04 no longer ships. `lsb-base` and `lsb-release` are installed for the same reason.
* Vitis is installed by the AMD installer into `/tools/Xilinx`, not by the Dockerfile. Python is not installed in the image; add it only if a tool asks for it.

## Runtime notes for `run.sh`

* `--network=host` shares the host network namespace, intended to help align the container with the license host ID. Still verify the ID.
* Device-cgroup rule `189` covers USB bus devices (USB-JTAG). Rule `188` covers USB serial devices. These are used instead of `--privileged`.
* `xhost +SI:localuser:<you>` is applied on start and revoked on exit, rather than opening X11 to every local user.
* Serial devices are passed through only if they exist when the container starts. Restart the container or add the device explicitly if plugged in later.
* `--ipc=host` can be tested if the GUI reports shared-memory errors. It is off by default.

## Optional: store Vivado on a larger disk

If the default Docker storage is too small, use a host directory on the larger disk:

```bash
sudo mkdir -p /data/xilinx
sudo chown "$(id -u):$(id -g)" /data/xilinx

export XILINX_TOOLS_MOUNT=/data/xilinx
./docker/run.sh
```

The script mounts that directory at `/tools/Xilinx`. A host directory also makes the install visible and easy to back up.

Previous: [Licensing](02-licensing.md) | Next: [Install and verify Vivado](04-install-vivado.md)
