# 1. Host setup

Install Docker Engine, verify storage, create the host folders that hold the Vivado install, and keep the installer and license outside the Git repository.

## 1.1 Install Docker Engine

Follow [Docker's official instructions for Ubuntu](https://docs.docker.com/engine/install/ubuntu/). Docker officially supports Ubuntu 26.04, 24.04, and 22.04 as hosts.

```bash
sudo systemctl status docker --no-pager
# If not running:
sudo systemctl enable --now docker

sudo docker run --rm hello-world
```

### Optional: Run Docker without `sudo`

Check whether your account already belongs to the `docker` group:

```bash
id -nG
```

If `docker` is not listed, run:

```bash
getent group docker >/dev/null || sudo groupadd docker
sudo usermod -aG docker "$USER"
```

**Log out of your desktop session completely and log back in** to activate the updated group membership. Alternatively, restart the computer.

Verify access:

```bash
id -nG
docker run --rm hello-world
```

**Security note:** Membership in the `docker` group grants root-level privileges. Keep this in mind when deciding which users should have Docker access. See [Docker's official post-installation instructions](https://docs.docker.com/engine/install/linux-postinstall/).

## 1.2 Check storage and user ID

Reserve approximately **150 GB of free space** for Docker, Vivado, and build outputs. This is a conservative target, not a strict minimum.

```bash
id -u
DOCKER_ROOT="$(docker info --format '{{.DockerRootDir}}')"
echo "Docker Root Dir: $DOCKER_ROOT"
df -h / "$HOME" "$DOCKER_ROOT"
```

Do not assume Docker uses `/var/lib/docker`. Docker itself only stores the image (a few GB). Vivado is stored in host folders created in [1.5](#15-create-the-vivado-folders), so the filesystem that matters is the one holding `~/xilinx`. If it is too small, put those folders elsewhere: see [Changing the install location](03-docker-environment.md#changing-the-install-location).

## 1.3 Prepare the installer directory

```bash
mkdir -p "$HOME/installer"
```

Expected contents:

```text
~/installer/
├── FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_XXXX_XXXX_Lin64.bin
└── Xilinx.lic
```

The license is generated in [Licensing](02-licensing.md). Its filename here is illustrative.

```bash
cp /path/to/FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_XXXX_XXXX_Lin64.bin "$HOME/installer/"
chmod +x "$HOME/installer/FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_XXXX_XXXX_Lin64.bin"
```

For the Vivado GUI through X11 or XWayland, install the host display utility:

```bash
sudo apt update
sudo apt install -y x11-xserver-utils
```

## 1.4 Clone the repository

```bash
git clone https://github.com/yassine-cherni/soc_lab.git "$HOME/Desktop/soc_lab"
cd "$HOME/Desktop/soc_lab"

mkdir -p docker docs docs/images rtl hls constraints sim scripts
touch rtl/.gitkeep hls/.gitkeep constraints/.gitkeep sim/.gitkeep scripts/.gitkeep
```

## 1.5 Create the Vivado folders

The Vivado install and the container user's home live in two plain host folders, not in Docker volumes. This keeps the install safe when you delete or replace the container, rebuild the image, or run Docker cleanup commands.

```bash
mkdir -p "$HOME/xilinx/tools" "$HOME/xilinx/home"
```

| Host folder | Mounted at | Holds |
|---|---|---|
| `~/xilinx/tools` | `/tools/Xilinx` | the Vivado, Vitis, and Vitis HLS install |
| `~/xilinx/home` | `/home/vivado` | license copy, `~/.Xilinx` settings, install configuration |

Both folders must be owned by your user (UID 1000 on a default Ubuntu desktop), because the container user has the same UID. `docker/run.sh` creates them if missing and warns if the ownership is wrong. Keep these folders outside the Git repository.

Next: [Licensing](02-licensing.md)