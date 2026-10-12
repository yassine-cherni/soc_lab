# 4. Install and verify Vivado 2026.1

Run everything here **inside the container**.

Before installing, confirm the persistent mounts are in place and writable:

```bash
ls -ld /tools/Xilinx /home/vivado
touch /tools/Xilinx/.write_test && rm /tools/Xilinx/.write_test
```

Both directories should belong to `vivado`. They are backed by `~/xilinx/tools` and `~/xilinx/home` on the host. If the `touch` fails, fix the ownership on the host: `sudo chown -R "$(id -u):$(id -g)" ~/xilinx`.

The installer `.bin` is the Unified **web** installer. It downloads selected tools and device support from AMD, so internet access is required, even though the filename contains "SDI". Checksum retry messages during download are normal, the installer recovers on its own. If the installer or container stops mid-install, relaunch the container and rerun the installer. It resumes from where it stopped.

On a slow or unreliable connection, consider the offline route: run the web installer once with the **Download Only** option to build a single-file image (about 98 GB), keep it on a disk, and install from that. In that case skip 4.3 (authentication is only for the web installer) and run `xsetup` from the extracted image instead of `/tmp/sdi`.

The installer must already be executable (done on the host in [Host setup](01-host-setup.md#13-prepare-the-installer-directory)). Do not `chmod` it inside the container. If you see `Read-only file system`, run `chmod +x` on the host file instead.

## 4.1 Extract the installer

```bash
cd /installer

./FPGAs_AdaptiveSoCs_Unified_SDI_2026.1_XXXX_XXXX_Lin64.bin \
    --noexec --target /tmp/sdi
```

Replace `XXXX_XXXX` with the numbers in your installer's filename (`ls /installer` shows it).

## 4.2 Check required libraries

The image already contains the legacy `libtinfo5` and `libncurses5` packages. If the installer still reports missing libraries, run AMD's script if present:

```bash
# Snapshot the installed packages first (used in 4.7 to update the Dockerfile)
mkdir -p /work/build
dpkg-query -W -f='${binary:Package}\n' | sort > /work/build/pkgs-before.txt

sudo apt-get update
dos2unix /tmp/sdi/installLibs.sh
sudo /tmp/sdi/installLibs.sh

# Save the full list and the packages the script added. These files live in
# /work, so they survive the container. An empty "added" list means the image
# already had everything.
dpkg-query -W -f='${binary:Package}\n' | sort > /work/build/pkgs-after-script.txt
comm -13 /work/build/pkgs-before.txt /work/build/pkgs-after-script.txt > /work/build/pkgs-added.txt
wc -l /work/build/pkgs-added.txt
```

If `pkgs-added.txt` is not empty, turn it into the Dockerfile's package list so a fresh container never needs the script again:

```bash
{ echo "# Packages added by AMD installLibs.sh (2026.1), captured $(date +%F)"
  cat /work/build/pkgs-added.txt; } > /work/docker/xilinx-libs.txt
```

The Dockerfile reads `docker/xilinx-libs.txt` (see [Docker environment](03-docker-environment.md)). Rebuild the image on the host when convenient; the running container is not affected.

The 2026.1 `installLibs.sh` has been shipped with Windows line endings, which fails with `$'\r': command not found`. The `dos2unix` line fixes that and is harmless if the file is already clean. Prefer running this script before the install; a post-install run can hit problems if some packages are missing beforehand.

If it is missing or fails, see AMD's [Checking Required Libraries](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Checking-Required-Libraries). Do not substitute a newer library ABI via symlink.

## 4.3 Authenticate

```bash
cd /tmp/sdi
./xsetup -b AuthTokenGen
```

Follow the prompts to sign in with your AMD account.

## 4.4 Generate the installation configuration

```bash
mkdir -p "$HOME/.Xilinx"
./xsetup -b ConfigGen
```

Choose option **1, Vitis** in the product menu. The configuration is saved to `/home/vivado/.Xilinx/install_config.txt`.

Vitis includes Vivado and Vitis HLS. They are not listed as separate modules in the generated file, so there is nothing to tick for them; confirm them after the install in 4.8 and 4.9. In the generated file every device family is set to `:0` (off) and only `DocNav:1` is on. The `Modules=` line is very long, so edit the file with `sed` instead of an editor:

```bash
sed -i \
  -e 's|^Destination=.*|Destination=/tools/Xilinx|' \
  -e 's|Zynq-7000 All Programmable SoC:0|Zynq-7000 All Programmable SoC:1|' \
  -e 's|DocNav:1|DocNav:0|' \
  -e 's|^CreateProgramGroupShortcuts=.*|CreateProgramGroupShortcuts=0|' \
  -e 's|^CreateDesktopShortcuts=.*|CreateDesktopShortcuts=0|' \
  -e 's|^CreateFileAssociation=.*|CreateFileAssociation=0|' \
  "$HOME/.Xilinx/install_config.txt"
```

What each line does:

* Sets `Destination=/tools/Xilinx`
* Enables only the **Zynq-7000 All Programmable SoC** device family
* Turns off Documentation Navigator (optional; leave `DocNav:1` if you want it)
* Disables Start menu, desktop, and file-association shortcuts, which are useless inside a container

Leave `InstallOptions=Acquire or Manage a License Key:0` as it is, since that option opens an interactive license step. Verify the edit:

```bash
grep -E '^(Destination|Create)' "$HOME/.Xilinx/install_config.txt"
grep -o '[^,=]*:1' "$HOME/.Xilinx/install_config.txt"
```

The first command should show the destination and three `=0` shortcut lines. The second should print only `Zynq-7000 All Programmable SoC:1`.

Prefer editing the AMD-generated configuration over writing the module list by hand.

## 4.5 Install

```bash
cd /tmp/sdi

./xsetup \
    --agree XilinxEULA,3rdPartyEULA \
    --batch Install \
    --config "$HOME/.Xilinx/install_config.txt"
```

Disk use and download time depend on the selected components, and Vitis adds noticeably more than Vivado alone. Check the disk-space figure the installer prints before the download starts. With only the Zynq-7000 family selected, the 2026.1 Vitis install was a 32.7 GB download and about 89 GB on disk afterwards (check with `du -sh ~/xilinx/tools` on the host). The expected environment script is `/tools/Xilinx/2026.1/Vivado/settings64.sh`. Because `/tools/Xilinx` is the host folder `~/xilinx/tools`, the install survives container deletion, image rebuilds, and Docker cleanups.

## 4.6 Copy the license into the persistent home

```bash
install -m 600 \
    /installer/Xilinx.lic \
    "$HOME/.Xilinx/Xilinx.lic"
```

Adjust the source path if your license has a different name. `/home/vivado` is backed by the host folder `~/xilinx/home`, so the license persists.

```bash
source /etc/vivado-env.sh
echo "$XILINXD_LICENSE_FILE"
test -r "$XILINXD_LICENSE_FILE" && echo "License file is readable"
```

The variable must point to the `.lic` file itself, not the `.Xilinx` directory. If you have two license files, copy both and set the variable to both paths separated by a colon.

Confirm the license matches this machine with the License Manager (needs the GUI):

```bash
vlm
```

Open **View Host Information** and check that an Ethernet MAC listed there is the one you licensed, then run **Perform Diagnostics** under License Diagnostics. `XILINXD_LICENSE_FILE` must show as passing. `LM_LICENSE_FILE` showing as failing is expected for a node-locked license.

You can also confirm the match without the GUI. When Vivado starts in batch mode (see 4.8), it prints `A valid Vivado Design Suite BASIC license has been detected` followed by the expiry date. A node-locked license that does not match this machine is not accepted, so that line means the host ID matches.

The Basic license expires after a year. To renew, generate a new license, overwrite `$HOME/.Xilinx/Xilinx.lic`, and repeat this check.

## 4.7 Post-install libraries

When the install finishes, the installer asks you to run `installLibs.sh` from the Vitis scripts folder. In 2026.1 both `Vitis/scripts` and `Vivado/scripts` contain a copy, so list them first, since paths can differ between releases:

```bash
find /tools/Xilinx -name installLibs.sh 2>/dev/null
find /tools/Xilinx -name settings64.sh 2>/dev/null
```

Take a package snapshot, run the script, and record what it added:

```bash
cd /tmp
dpkg-query -W -f='${binary:Package}\n' | sort > /work/build/pkgs-before-post.txt

sudo apt-get update
dos2unix /tools/Xilinx/2026.1/Vitis/scripts/installLibs.sh
sudo /tools/Xilinx/2026.1/Vitis/scripts/installLibs.sh

dpkg-query -W -f='${binary:Package}\n' | sort > /work/build/pkgs-after-post.txt
comm -13 /work/build/pkgs-before-post.txt /work/build/pkgs-after-post.txt > /work/build/pkgs-added-post.txt
wc -l /work/build/pkgs-added-post.txt
exec bash
```

If you already ran the same script in 4.2, this run usually installs nothing new, so `pkgs-added-post.txt` is empty. The script writes a root-owned log (`installLibs.sh_<timestamp>`) into the directory you run it from, which is why the block starts with `cd /tmp`. If a log landed in your persistent home, remove it with `sudo rm -f ~/installLibs.sh_*`.

The script may print `Package 'libasound2' has no installation candidate`. On Ubuntu 24.04 that package is named `libasound2t64`, which the Dockerfile already installs, so this message is harmless. The script continues with the remaining packages.

The `Vivado/scripts` copy may list different packages from the Vitis one. Compare them while ignoring line endings (after `dos2unix` on one copy, a plain `diff` reports every line as different even when the content is the same):

```bash
diff <(tr -d '\r' < /tools/Xilinx/2026.1/Vitis/scripts/installLibs.sh) \
     <(tr -d '\r' < /tools/Xilinx/2026.1/Vivado/scripts/installLibs.sh) && echo "identical"
```

If they are identical, running the Vitis copy is enough. If they differ, run the Vivado one the same way (`dos2unix`, then `sudo`).

If the script fails, diagnose the missing library from AMD's documentation instead of creating compatibility symlinks.

**Make the libraries permanent.** Packages installed here live in the container filesystem and are lost on exit. If `pkgs-added-post.txt` is not empty, merge it into the Dockerfile's package list without duplicates:

```bash
cd /work
{ head -n 1 docker/xilinx-libs.txt
  grep -hv '^#' docker/xilinx-libs.txt build/pkgs-added-post.txt | sort -u; } > build/xilinx-libs.new
mv build/xilinx-libs.new docker/xilinx-libs.txt
cp build/pkgs-after-post.txt build/pkgs-after-script.txt
wc -l docker/xilinx-libs.txt
```

Commit `docker/xilinx-libs.txt` and rebuild the image. The Vivado install and your license are untouched by a rebuild. Do this as soon as the libraries are known, so a fresh container never needs the script again.

To confirm a rebuilt image has everything the scripts installed, run this in a fresh container; it should print nothing:

```bash
comm -13 <(dpkg-query -W -f='${binary:Package}\n' | sort) /work/build/pkgs-after-script.txt
```

## 4.8 Verify

Check the version:

```bash
vivado -version
```

It should report **Vivado v2026.1**. If it will not launch, check the license path, license validity, and missing-library errors. If `vivado` is not found, check that `/tools/Xilinx/2026.1/Vivado/settings64.sh` exists and open a new shell.

Check the target device:

```bash
mkdir -p /work/build && cd /work/build
cat > /tmp/check_device.tcl <<'TCL'
set part "xc7z020clg484-1"
set found [get_parts $part]

if {[llength $found] == 0} {
    puts stderr "ERROR: Target part $part was not found."
    exit 1
}

puts "Target device available: $found"
exit 0
TCL

vivado -mode batch -source /tmp/check_device.tcl
```

Expect `Target device available: xc7z020clg484-1`, and near the top the line `A valid Vivado Design Suite BASIC license has been detected` with your expiry date. This verifies the device database only. No physical board is required. If the part is missing, rerun the installer and add the Zynq-7000 family.

## 4.9 Verify Vitis HLS

The HLS command-line entry points have changed between releases (`vitis_hls`, `vitis-run`, `v++`), so list what your install provides:

```bash
find /tools/Xilinx/2026.1 -type f \( -name vitis-run -o -name v++ -o -name vitis_hls \) 2>/dev/null
```

In 2026.1 the entry points `vitis-run` and `v++` are in `Vitis/bin` and are on `PATH` once `vivado-env.sh` is sourced. `vitis_hls` exists only under `bin/unwrapped/lnx64.o`, so use `vitis-run` or `v++` instead. Run `vitis-run --version`; it should report v2026.1. If it is not on your `PATH` in a new shell, locate the right settings file with `find /tools/Xilinx/2026.1 -maxdepth 2 -name settings64.sh`. `vivado-env.sh` already sources the Vivado, Vitis, and Vitis_HLS ones if they exist at those paths; adjust the list in that file if yours differ.

To confirm the HLS license is in the file you installed:

```bash
grep -E '^(FEATURE|INCREMENT)' "$XILINXD_LICENSE_FILE" | awk '{print $2}'
```

For 2026.1 the list should show `Vivado_Basic_Package`, `Vivado_Simulation`, `Vivado_Synthesis`, `Vivado_Implementation`, and `Vitis_HLS`. The names are AMD's and may change in other releases, so compare against what the portal showed you.

## 4.10 Prove the install is permanent

Do this once everything above passes. It simulates what you wanted to be safe: a replaced container, then a replaced image.

1. Exit the container, then start a new one with `./docker/run.sh`. Run `vivado -version` and `vitis-run --version` (or whichever HLS command 4.9 found). Both should work with no reinstall.
2. On the host, rebuild the image. Keep the old one under a second tag first, so a failed build (for example a 404 on the pinned `libtinfo5`) cannot leave you without an image:

   ```bash
   docker tag vivado-base:24.04 vivado-base:backup
   docker build --build-arg UID="$(id -u)" -t vivado-base:24.04 docker/
   ./docker/run.sh
   ```

   Inside the new container, run `vivado -version`, `vitis-run --version`, and the package check from 4.7, which should print nothing. If something fails on a missing library, the packages from 4.7 are not yet in `docker/xilinx-libs.txt`. When everything passes, remove the fallback with `docker rmi vivado-base:backup`.
3. On the host, confirm the install and license are real files you can see and back up:

   ```bash
   du -sh ~/xilinx/tools ~/xilinx/home
   ls -l ~/xilinx/home/.Xilinx/Xilinx.lic
   find ~/xilinx -not -user "$USER" | head
   ```

   Expect about 89 GB for `tools`, tens of MB for `home`, a license file owned by you with mode `-rw-------`, and no output from `find`. Anything `find` lists is owned by root, usually a log written by a `sudo` script; remove it with `sudo rm` inside the container.

Previous: [Docker environment](03-docker-environment.md) | Next: [ZC702 hardware access](05-zc702-hardware.md)