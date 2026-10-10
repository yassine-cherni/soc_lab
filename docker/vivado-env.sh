#!/usr/bin/env bash

for tool in Vivado Vitis Vitis_HLS; do
    if [ -f "/tools/Xilinx/2026.1/$tool/settings64.sh" ]; then
        source "/tools/Xilinx/2026.1/$tool/settings64.sh"
    fi
done

export XILINXD_LICENSE_FILE="${XILINXD_LICENSE_FILE:-$HOME/.Xilinx/Xilinx.lic}"
