# Examples

This directory contains a curated set of examples demonstrating either the use of the modules found
in this repository or some aspect of BSV and how it interacts with various tools to produce working
bitstreams for some sample set of development boards. We use these primarily to demonstrate some
small aspect of capability in a known, small design before incorporating it into more complicated
scenarios.

We hope these examples are useful for others as they explorer the use of Bluespec (and to a lesser
degree the synthesis tooling) and we intend to steadily grow this set over time. Note that the
modules found in this directory are board (or for that matter simulator) agnostic. For board
specific instantiations, please see the ```Examples.bsv``` file in each of the respective board
directories under [hdl/boards](hdl/boards).

## Contents

To date we have the following on offer:

### Blinky

Every new dev board needs a blinky. The ```Blinky(..)``` interface outputs two LED bits, one steady
blinking at a frequency of 1Hz and one indicating whether or not the ```button_pressed()``` method
is called. Please see the ```mkBlinky``` module in the ```Examples.bsv``` file for each board on how
this module interacts with a top interface defined by a constraint file.

### UART loopback

Slightly more interesting than a blinky is the ```UARTLoopback(..)```. It combines a UART receiver
and transmitter back to back, including useful examples of the ```Strobe(..)``` and
```BitSampler(..)``` interfaces, to echo back any received characters. In addition to the modules
found in this repository, it shows how the ```GetPut``` interfaces found in the BSV standard library
can be used to chain together different modules while preserving local reasoning.

A two character test bench using Bluesim can be run from the Cobble ```build``` directory as
follows:

```
$ ./cobble build latest/hdl/examples/uart_loopback_test && latest/hdl/examples/uart_loopback_test
'h55
'haa
```
