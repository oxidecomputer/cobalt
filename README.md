# Cobalt

Hi there, welcome to Cobalt. Cobalt is a collection of [Bluespec](https://github.com/B-Lang-org/bsc)
interfaces and modules, used by [Oxide Computer](https://github.com/oxidecomputer) to implement
custom logic for its [new computer](https://www.youtube.com/watch?v=vvZA9n3e5pc). Since we developed
some of these pieces on readily
[available](https://www.latticesemi.com/products/developmentboardsandkits/ecp5evaluationboard)
[development](https://radiona.org/ulx3s/) [boards](https://www.latticesemi.com/icestick) using a
fully open source [synthesis](https://github.com/YosysHQ/yosys)
[toolchain](https://github.com/YosysHQ/nextpnr), we figured this work and the implementation of its
[build system](https://github.com/cbiffle/cobble-build) may serve as practical examples for others
on how to use Bluespec in their own projects.

## Getting Started

To get started with the examples found in this repo you may want to follow the following steps to
get up and running.

### Clone the Repo

To clone the repo, including its Cobble dependency, run the following. Use the URL
```git@github.com:oxidecomputer/cobalt``` if SSH is your transport of choice.
```
git clone --recursive https://github.com/oxidecomputer/cobalt
```

If you happen to have cloned the repo without the submodules, you can initialize them like so:
```
git submodule update --init --recursive
```

### Docker Option (pre-configured with Bluespec Compiler and Synthesis Toolchain)

Rather than manually installing the toolchains below, you can build a Docker image using the Dockerfile
in this repository. From the cobalt checkout directory, build the Docker image using the command:
`docker build .`

The docker image has the bluespec tools installed in `/opt/bluespec/` and the synthesis tools installed
in `/opt/fpga-toolchain`, and both `/opt/bluespec/bin/`  and `/opt/fpga-toolchain/bin/` locations are
added to the PATH env variable.

### Bare metal Option (install the toolchains yourself)
#### Install the Bluespec Compiler

The Bluespec compiler is currently only available in source form. Please head over to the [build
instructions](https://github.com/B-Lang-org/bsc#compiling-bsc-from-source) and install yourself a
copy.

You should also install the Bluespec libraries from source. Note that these will require the bsc
installation above, and expect bsc to be on your path since they use the compiler. Please head
over to the [build instructions](https://github.com/B-Lang-org/bsc-contrib) and install the libraries.

#### Install the Synthesis Toolchain

The easiest way to get the Yosys/nextpnr synthesis toolchain installed is by heading over to
[YosysHQ](https://github.com/YosysHQ/fpga-toolchain) and downloading a build for your favorite OS.
Alternatively, the [Yosys](https://github.com/YosysHQ/yosys) and
[nextpnr](https://github.com/YosysHQ/nextpnr) repos have build instructions if you'd rather build
from source.

#### Additional Dependencies

Finally, Cobble requires a Python 3 (version 3.6+ is probably sufficient, we do not actually know).
Please install a copy if your system does not already have one.

Cobble also requires the python package 'ninja' so you'll need to 
```
pip install ninja
```

### Set BUILD.vars

In order to point Cobble at the right toolchain pieces, copy ```BUILD.vars.example``` and edit the
paths in this file to match your installed toolchain:
```
cp BUILD.vars.example BUILD.vars
$EDITOR BUILD.vars
```

### Initialize Build Graph, Build Examples

*Note:* If using the docker image, following these instructions is best done
with the interactive shell and mapping checkouts. Also note that if you're
on Windows and doing git checkouts on windows, python will be unhappy with
the windows line endings so you should checkout with `LF` only on the windows side.

And at long last we are ready to initialize the build graph and build one of the examples like so:
```
mkdir build; cd build
../vnd/cobble/cobble init ..
```

To build and run one of the test benches:
```
./cobble build latest/hdl/examples/uart_loopback_test && latest/hdl/examples/uart_loopback_test
```

The output of the command above should be the following, indicating successful "transmission" of two
bytes:
```
% latest/hdl/examples/uart_loopback_test
'h55
'haa
```

To build the Blinky example Lattice ECP5 EVN board and flash the SRAM of the FPGA:
```
./cobble build latest/hdl/boards/ecp5_evn/blinky_ecp5_evn.bit
ecpprog -S latest/hdl/boards/ecp5_evn/blinky_ecp5_evn.bit
```

Finally, to build all possible targets simply run:
```
./cobble build
```

If you are wondering where to go from here, we suggest heading over to the [examples](hdl/examples)
directory or building and trying one of the bitstreams for the other supported [boards](hdl/boards).
Happy hacking!

## FAQ

Q: Bluesim test benches fail with the following error:
```
latest/hdl/examples/uart_loopback_test: line 3: bluetcl: command not found
latest/hdl/examples/uart_loopback_test: line 12: /tcllib/bluespec/bluesim.tcl: No such file or directory
latest/hdl/examples/uart_loopback_test: line 12: exec: /tcllib/bluespec/bluesim.tcl: cannot execute: No such file or directory
```

A: Make sure the bluetcl can be found using the ```$PATH``` variables. If the Bluespec compiler was
installed outside the usual system paths, because its ```bin``` direction is present in ```$PATH```.
