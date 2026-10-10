# soc_lab

Programmable robot controller (FSM, datapath, motor controller) written in VHDL for the AMD Zynq-7000 ZC702 board. Vivado handles RTL synthesis, implementation, timing analysis, and bitstream generation.

Vitis HLS (C/C++-to-RTL blocks) is part of the toolchain alongside the handwritten VHDL flow. Vitis embedded software development (apps on the Zynq PS) is not set up here.

## Environment

| Item | Value |
|---|---|
| Host OS | Ubuntu 26.04 LTS, x86-64 |
| Container OS | Ubuntu 24.04 LTS (`ubuntu:24.04`) |
| FPGA tools | AMD Vivado Design Suite 2026.1 and Vitis HLS |
| Installer | `FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_XXXX_XXXX_Lin64.bin` |
| Board | AMD Zynq-7000 ZC702 |
| Part | `xc7z020clg484-1` |

**Compatibility:** AMD's 2026.1 OS table lists Ubuntu 24.04 through 24.04.3. Ubuntu 24.04.5 is not explicitly listed, so treat this setup as tested, not officially certified.

**Host OS:** AMD's installer support list does not cover Ubuntu 26.04, but that does not matter here because Vivado runs inside the Ubuntu 24.04 container. The host only needs Docker.

**Version:** This setup targets the original 2026.1 release. The Basic license does not support minor updates such as 2026.1.1, and 2026.1.1 adds nothing for the XC7Z020.

**License:** Vivado Basic and Vitis HLS are both free. Basic is annual, so renew it once a year ([Licensing](docs/02-licensing.md)).

## Quick start

1. [Host setup](docs/01-host-setup.md): Docker Engine, disk space, installer directory
2. [Licensing](docs/02-licensing.md): generate the free Basic and Vitis HLS node-locked licenses
3. [Docker environment](docs/03-docker-environment.md): build the image, start the container
4. [Install and verify Vivado and Vitis HLS](docs/04-install-vivado.md): installer, license, version and device check
5. [ZC702 hardware access](docs/05-zc702-hardware.md): optional, JTAG and UART
6. [VHDL lab notes](docs/06-vhdl-lab-notes.md): ISE to Vivado migration points
7. [Troubleshooting](docs/troubleshooting.md)

## Persistence

The container is discarded on exit. Only `/work`, `/tools/Xilinx`, `/home/vivado`, and `/installer` survive, so add any extra packages to `docker/Dockerfile`. See [Docker environment](docs/03-docker-environment.md) for details and the host-folder variables.

## Repository layout

```text
soc_lab/
├── docker/
│   ├── Dockerfile
│   ├── run.sh
│   └── vivado-env.sh
├── docs/
│   └── images/
├── rtl/
├── hls/
├── constraints/
├── sim/
├── scripts/
├── .gitignore
└── README.md
```

## Git hygiene

Commit Docker config, VHDL sources, constraints, and Tcl scripts. Never commit installers, licenses (`*.lic`), or generated binaries (`*.bit`, `*.bin`, `*.xsa`). See `.gitignore`. Keep the installer and license in `~/installer`, outside this repository.

```bash
git status
git add docker/ docs/ rtl/ hls/ constraints/ sim/ scripts/ README.md .gitignore
git commit -m "Add Vivado 2026.1 Docker environment"
```

Push after verifying the remote and branch.

## Official documentation

* [UG973: Release Notes, Installation, and Licensing](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license)
* [UG1165: Setting Up the Board](https://docs.amd.com/r/en-US/ug1165-zynq-embedded-design-tutorial/Setting-Up-the-Board)
* [UG850: ZC702 Evaluation Board User Guide](https://docs.amd.com/v/u/en-US/ug850-zc702-eval-bd)
