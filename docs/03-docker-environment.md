# 3. Docker environment

The configuration lives in `docker/`:

| File | Purpose |
|---|---|
| [`docker/Dockerfile`](../docker/Dockerfile) | Ubuntu 24.04 image with Vivado dependencies and a `vivado` user |
| [`docker/xilinx-libs.txt`](../docker/xilinx-libs.txt) | Extra packages from AMD's `installLibs.sh`, one per line, installed by the Dockerfile |
| [`docker/run.sh`](../docker/run.sh) | Starts the container with X11, USB, host folders, and host networking |
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

Make sure the Vivado folders exist first ([Host setup, 1.5](01-host-setup.md#15-create-the-vivado-folders)). `run.sh` also creates them if they are missing.

Run whenever you want to open the Vivado environment:

```bash
cd "$HOME/Desktop/soc_lab"
./docker/run.sh
```

If the script is not executable, run `chmod +x docker/run.sh` once.

The container starts in `/work`, mapped to the host's `soc_lab` repository.

Check that the GUI path works before installing anything (the installer, `vlm`, and Vivado all need it):

```bash
echo "$DISPLAY"
xdpyinfo | head -n 3
```

`xdpyinfo` should print the X server version. If it reports `Authorization required` or `unable to open display`, see the GUI entry in [Troubleshooting](troubleshooting.md).

### Second terminal, and batch commands

The container is named `vivado`. To open another shell in the running container, use:

```bash
docker exec -it vivado bash
```

Do not start a second `run.sh` for this: it fails with a name conflict, and when either `run.sh` exits it revokes the X11 permission the other one is using.

The Vivado environment is loaded by interactive shells only. A non-interactive command such as `./docker/run.sh vivado -version` will not find `vivado`. Run batch work through an interactive shell:

```bash
./docker/run.sh bash -ic 'cd /work/build && vivado -mode batch -source /work/scripts/build.tcl'
```

Vivado writes `vivado.log`, `vivado.jou`, and `.Xil/` into the directory it is started from, so start it from `/work/build` (ignored by Git) rather than the repository root.

## What persists and what does not

The container runs with `--rm`, so its own filesystem is discarded on exit. Only these paths survive:

| Container path | Backed by | Holds |
|---|---|---|
| `/work` | host repo (bind mount) | HDL sources, scripts, your projects |
| `/tools/Xilinx` | `~/xilinx/tools` (host folder) | the Vivado install |
| `/home/vivado` | `~/xilinx/home` (host folder) | license copy, `~/.Xilinx` settings and install config |
| `/installer` | `~/installer` (bind mount) | installer and license source files |

Everything else is lost, including files in `/tmp` and packages installed at runtime with `sudo apt-get`. Save work under `/work`, and put any extra library the tools need into the Dockerfile and rebuild (see [section 4.7](04-install-vivado.md#47-post-install-libraries)).

The Vivado install and home are plain host folders on purpose. They survive deleting or replacing the container, rebuilding or deleting the image, `docker volume prune`, `docker system prune`, and reinstalling Docker. Only deleting the folders themselves removes them.

## Configuration variables

Set these before running `run.sh`, for example `XILINX_TOOLS_MOUNT=/mnt/disk2/xilinx/tools ./docker/run.sh`.

| Variable | Default | Meaning |
|---|---|---|
| `XILINX_TOOLS_MOUNT` | `~/xilinx/tools` | Absolute host path mounted at `/tools/Xilinx` |
| `VIVADO_HOME_MOUNT` | `~/xilinx/home` | Absolute host path mounted at `/home/vivado` |
| `INSTALLER_DIR` | `~/installer` | Host directory mounted at `/installer` |

A value starting with `/` is treated as a host directory. `run.sh` creates it and warns if it is not owned by your UID, because the container user has your UID and would otherwise be unable to write there. A value that does not start with `/` is treated as a named Docker volume, which is not recommended for the Vivado install because Docker commands can delete it.

A host directory mounted at `/home/vivado` starts empty, so it does not carry the image's default dotfiles. The shell still loads `vivado-env.sh` through `/etc/bash.bashrc`.

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
* Vitis is installed by the AMD installer into `/tools/Xilinx`, not by the Dockerfile. Python 3 is installed as a dependency of the packages in `xilinx-libs.txt`, so no separate Python setup is needed.
* Rebuild the image with the same `--build-arg UID="$(id -u)"` every time. The Vivado files in `~/xilinx` are owned by that UID, and a different UID in the image would leave them unwritable.

## Runtime notes for `run.sh`

* `--network=host` shares the host network namespace, intended to help align the container with the license host ID. Still verify the ID.
* Device-cgroup rule `189` covers USB bus devices (USB-JTAG). Rule `188` covers USB serial devices. These are used instead of `--privileged`.
* `xhost +SI:localuser:<you>` is applied on start and revoked on exit, rather than opening X11 to every local user.
* Serial devices are passed through only if they exist when the container starts. Restart the container or add the device explicitly if plugged in later.
* `--ipc=host` can be tested if the GUI reports shared-memory errors. It is off by default.
* With host networking, a `hw_server` started inside the container (TCP port 3121) is typically reachable from your LAN while it runs. That is fine on a trusted network; otherwise block the port with your firewall.

## Changing the install location

The default `~/xilinx` is on your home filesystem. If another disk has more room, or you want the install somewhere else, keep the same two-folder layout:

```bash
sudo mkdir -p /mnt/disk2/xilinx/tools /mnt/disk2/xilinx/home
sudo chown -R "$(id -u):$(id -g)" /mnt/disk2/xilinx
```

Use a Linux filesystem (ext4, xfs, btrfs) that is not mounted `noexec`. Do not use NTFS, exFAT, or FAT: the Vivado install needs symlinks and Unix permissions, and the installer fails or the tools misbehave without them.

Then either export the variables in `~/.bashrc` so every terminal uses them:

```bash
export XILINX_TOOLS_MOUNT=/mnt/disk2/xilinx/tools
export VIVADO_HOME_MOUNT=/mnt/disk2/xilinx/home
```

or change the two default lines near the top of `docker/run.sh`. If you already installed, stop the container and move the existing folders first (`mv ~/xilinx/tools /mnt/disk2/xilinx/tools`, same for `home`, or `cp -a` across filesystems). Always set both variables to the same pair of folders, or the container will see an empty install.

## Migrating from named volumes

Skip this if you never installed Vivado with the older `vivado-tools` and `vivado-home` Docker volumes. If you did, copy their contents into the host folders once. `cp -a` keeps ownership:

```bash
mkdir -p "$HOME/xilinx/tools" "$HOME/xilinx/home"

docker run --rm \
    -v vivado-tools:/from -v "$HOME/xilinx/tools":/to \
    ubuntu:24.04 cp -a /from/. /to/

docker run --rm \
    -v vivado-home:/from -v "$HOME/xilinx/home":/to \
    ubuntu:24.04 cp -a /from/. /to/
```

Start the container with `./docker/run.sh` and run `vivado -version`. After it works, the old volumes can be removed with `docker volume rm vivado-tools vivado-home`. A volume that holds only 4 KB was never installed into, so there is nothing to copy.

## Backups

* Back up `~/xilinx/home`. It is small and holds the copied license and Vivado settings: `tar czf vivado-home-backup.tar.gz -C ~/xilinx home`.
* Keep the original license file in `~/installer`. It is also available from the AMD licensing portal.
* The install in `~/xilinx/tools` is large and can be re-downloaded, so backing it up is optional.
* To be able to restore the image even if the pinned `libtinfo5` download disappears, save it once: `docker save vivado-base:24.04 | gzip > vivado-base.tar.gz`, and restore with `docker load < vivado-base.tar.gz`.

Previous: [Licensing](02-licensing.md) | Next: [Install and verify Vivado](04-install-vivado.md)