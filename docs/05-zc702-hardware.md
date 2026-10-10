# 5. ZC702 hardware access (optional)

Only needed for later hardware bring-up. Not required to install Vivado or verify the device database.

## 5.1 Connections and switches

| Item | Purpose | Cable |
|---|---|---|
| U23 | USB-JTAG (programming, debugging) | USB micro-B |
| J17 | Silicon Labs CP2103GM USB-to-UART bridge | USB mini-B |
| SW10 | JTAG select: must choose USB-JTAG (bit 1 = 0, bit 2 = 1, where 0 is open and 1 is closed) | none |

Do not use J1 for JTAG. Confirm against the board labels and [UG1165: Setting Up the Board](https://docs.amd.com/r/en-US/ug1165-zynq-embedded-design-tutorial/Setting-Up-the-Board).

## 5.2 Install cable rules on the host

The ZC702's USB-JTAG is a Digilent module, so the Digilent rules are the ones you need. Inside the container, locate the AMD cable-driver directory first, since its location has differed between releases:

```bash
find /tools/Xilinx/2026.1 -type d -name install_drivers
```

Then copy the `.rules` files from that directory to the shared installer directory:

```bash
cp <install_drivers directory>/*.rules /installer/
```

On the host:

```bash
sudo cp "$HOME"/installer/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Replug the JTAG cable afterward.

## 5.3 Check UART access

With the UART cable plugged in and the board powered:

```bash
ls /dev/ttyUSB*
picocom -b 115200 /dev/ttyUSB0
```

`run.sh` passes through serial devices present at container start. Restart the container or add the device explicitly if plugged in later.

Previous: [Install and verify Vivado](04-install-vivado.md) | Next: [VHDL lab notes](06-vhdl-lab-notes.md)
