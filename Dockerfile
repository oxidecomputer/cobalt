FROM ubuntu:20.04

# Fixed SHAs for Bluespec checkouts
ARG bsc_sha=ad02e9317ae9d808f6011567bae5c14cbd6753ec
ARG bsc_contrib_sha=894817ba81351448264ecfddc0afeffec9d7d8b0
# Fixed Release URLs for YosysHQ FPGAtoolchain release
ARG fpga_tools_url=https://github.com/YosysHQ/fpga-toolchain/releases/download/nightly-20210708/fpga-toolchain-linux_x86_64-nightly-20210708.tar.xz

RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        # Bluespec compiler requirements as documented: https://github.com/B-Lang-org/bsc#compiling-bsc-from-source
        git \
        ghc \
        wget \
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
        # cobble needs python and pip to install dependencies
        python3-pip \
        python3-dev && \
        rm -rf /var/lib/apt/lists/*

# Add bluespec tools, ninja executable, and fpga toolchain bins to path
ENV PATH="/opt/bluespec/bin:/opt/fpga-toolchain/bin:${PATH}"

# Download the Bluespec toolchains at specific reference SHAs and install bluespec
# to /opt/bluespec
RUN mkdir /bluespec && cd /bluespec && \
    # Checkout specific sha of bluespec compiler
    git clone --recursive https://github.com/B-Lang-org/bsc.git bsc && \
    cd bsc && git checkout $bsc_sha  && \
    # install bsc to /opt/bluespec
    make PREFIX=/opt/bluespec install && cd .. && \
    # Checkout specific sha of bluespec contrib
    git clone --recursive https://github.com/B-Lang-org/bsc-contrib bsc-contrib && \
    cd bsc-contrib && git checkout $bsc_contrib_sha && \
    # install bsc-contrib to /opt/bluespec
    make PREFIX=/opt/bluespec install && cd ../.. && \
    # Delete sources to keep image smaller
    rm -rf /bluespec

# Download, extract an install FPGA toolchains
RUN mkdir /opt/fpga-toolchain && \
    # download pre-built FPGA toolchain
    wget $fpga_tools_url && \
    # Extract to desired tool location
    tar -xf *.xz -C /opt/fpga-toolchain && \
    # Remove donwloaded archive to keep image smaller
    rm -rf *.xz

# Install cobble dependency (ninja)
RUN pip install ninja
