FROM --platform=linux/amd64 ubuntu:24.04

ARG UID=1000

# Legacy ncurses 5 (Vivado expects libtinfo.so.5, absent from Ubuntu 24.04 main).
# If this download ever returns 404, update these three ARGs
# (see docs/03-docker-environment.md).
ARG NCURSES5_VERSION=6.3-2ubuntu0.3
ARG LIBTINFO5_SHA256=4df4288404108f1a156d014e8764a064e977e34e6d44931ab60451694c03c90d
ARG LIBNCURSES5_SHA256=58da01991712c6856af0658dc5e9cb533c1a6854ab950055ade185e35bc9c276

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales tzdata ca-certificates curl git sudo nano unzip xz-utils \
    tmux dos2unix lsb-base lsb-release \
    iproute2 usbutils libusb-1.0-0 udev \
    build-essential make gcc-multilib g++-multilib \
    xauth x11-utils x11-xserver-utils xvfb fontconfig fonts-dejavu-core \
    libtinfo6 libncurses6 libstdc++6 \
    libx11-6 libxext6 libxrender1 libxtst6 libxi6 libxrandr2 libxft2 libsm6 \
    libxcomposite1 libxdamage1 libxfixes3 libxkbfile1 libxss1 libxshmfence1 \
    libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-render-util0 libxcb-shape0 \
    libgtk-3-0t64 libgtk2.0-0t64 libglib2.0-0t64 libgl1 libglu1-mesa libgbm1 \
    libdrm2 libasound2t64 libnss3 libsecret-1-0 libatk-bridge2.0-0t64 \
    libcups2t64 libpango-1.0-0 libcairo2 libfontconfig1 libdbus-1-3 \
    libcanberra-gtk-module \
    picocom \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Real legacy packages, downloaded over HTTPS and checksum-verified.
# Never replace these with libtinfo.so.6 symlinks: the ABIs differ.
RUN set -eux; \
    base=https://security.ubuntu.com/ubuntu/pool/universe/n/ncurses; \
    cd /tmp; \
    curl -fsSLO "$base/libtinfo5_${NCURSES5_VERSION}_amd64.deb"; \
    curl -fsSLO "$base/libncurses5_${NCURSES5_VERSION}_amd64.deb"; \
    echo "${LIBTINFO5_SHA256}  libtinfo5_${NCURSES5_VERSION}_amd64.deb" | sha256sum -c -; \
    echo "${LIBNCURSES5_SHA256}  libncurses5_${NCURSES5_VERSION}_amd64.deb" | sha256sum -c -; \
    apt-get install -y --no-install-recommends \
        "./libtinfo5_${NCURSES5_VERSION}_amd64.deb" \
        "./libncurses5_${NCURSES5_VERSION}_amd64.deb"; \
    rm -f /tmp/*.deb

# lmutil, lmgrd and the Vivado License Manager (vlm) look for the LSB loader,
# which Ubuntu 24.04 no longer ships. Point it at the real one.
RUN ln -s /lib64/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3

# Remove the stock UID 1000 user, then create ours with the host UID.
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && useradd -m --uid "${UID}" --shell /bin/bash \
       --groups sudo,dialout vivado \
    && printf '%s\n' 'vivado ALL=(ALL) NOPASSWD:ALL' \
       > /etc/sudoers.d/vivado \
    && chmod 0440 /etc/sudoers.d/vivado \
    && mkdir -p /tools/Xilinx /work \
    && chown vivado:vivado /tools/Xilinx /work

COPY vivado-env.sh /etc/vivado-env.sh

RUN printf '%s\n' 'source /etc/vivado-env.sh' >> /etc/bash.bashrc

USER vivado

WORKDIR /work

CMD ["/bin/bash"]
