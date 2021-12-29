FROM ubuntu:20.04

ARG USERNAME=dev
ARG UID=1000
ARG GID=$UID
ARG HOME=/home

ARG INSTALL_PREFIX=/usr/local

# Pinned versions to caching these images.
ARG BSC_URL=https://github.com/B-Lang-org/bsc.git
ARG BSC_SHA=61dc0ebbbea3a853d061556ae8828dc16e687e40
ARG BSC_CONTRIB_URL=https://github.com/B-Lang-org/bsc-contrib.git
ARG BSC_CONTRIB_SHA=d2b17aab4f2eacb79816624017961144de6e231f

ARG OSS_CAD_RELEASE_URL=https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2021-12-28/oss-cad-suite-linux-ARCH-20211228.tgz

# Create a non-root user, owning /home
RUN groupadd --gid $GID $USERNAME && \
    useradd --uid $UID --gid $GID -d $HOME $USERNAME && \
    chown $UID:$GID $HOME && \

    # Add sudo support, just in case.
    mkdir -p /etc/sudoers.d && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        sudo \
        wget \
        # Bluespec compiler requirements as documented in
        # https://github.com/B-Lang-org/bsc#compiling-bsc-from-source.
        git \
        ghc \
        libghc-regex-compat-dev \
        libghc-syb-dev \
        libghc-old-time-dev \
        libghc-split-dev \
        tcl-dev \
        autoconf \
        gperf \
        flex \
        bison \
        pkg-config \
        # Cobble deps, Python 3 comes with the OSS CAD suite below.
        ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Use Bash so string substitution is available.
SHELL ["/bin/bash", "-c"]
RUN DPKG_ARCH="$(/usr/bin/dpkg --print-architecture)" && \
    # Determine the correct suite architecture.
    case "${DPKG_ARCH##*-}" in \
        amd64) ARCH='x64';; \
        arm64) ARCH='arm64';; \
        *) echo "Unsupported Architecture"; exit 1 ;; \
    esac && \

    # Push OSS_CAD_RELEASE_URL contents into Bash context.
    URL=$OSS_CAD_RELEASE_URL && \

    # Fetch and install tarball.
    wget --progress=bar:force:noscroll ${URL//ARCH/${ARCH}} -O /tmp/oss-cad-suite.tgz && \
    tar -xf /tmp/oss-cad-suite.tgz --strip-components=1 -C $INSTALL_PREFIX && \

    # Clean up.
    rm -f /tmp/oss-cad-suite.tgz

# Expose Bluespec and the Python3 binaries from the OSS CAD suite.
ENV PATH="${PATH}:$INSTALL_PREFIX/py3bin:$INSTALL_PREFIX/bluespec/bin"

# Fetch the the Bluespec toolchain at the specified SHA.
RUN git clone --recursive $BSC_URL /tmp/bsc && cd /tmp/bsc && \
    git checkout $BSC_SHA && git submodule update -f && \
    # Build, install and clean up.

    # Unfortunately the Bluespec build infrastructure conflates its own library
    # resources and the Bluespec and Verilog standard libraries for design
    # builds, so use a seperate prefix rather than mixing with OSS CAD suite.
    make PREFIX=$INSTALL_PREFIX/bluespec install-src && \
    rm -rf /tmp/bsc

# Fetch BSC Contrib at the specified SHA.
RUN git clone --recursive $BSC_CONTRIB_URL /tmp/bsc-contrib && cd /tmp/bsc-contrib && \
    git checkout $BSC_CONTRIB_SHA && git submodule update -f && \
    # Build, install and clean up.
    make PREFIX=$INSTALL_PREFIX/bluespec install && \
    rm -rf /tmp/bsc-contrib

USER $USERNAME
WORKDIR $HOME
