# -*- python -*- vim:syntax=python:

bluespec_library('ULX3S',
    sources = [
        'ULX3S.bsv',
    ],
    deps = [
        '//hdl/interfaces:ECP5',
    ])

bluespec_verilog('examples',
    top = 'Examples.bsv',
    modules = [
        'mkBlinky',
        'mkUARTLoopback',
    ],
    deps = [
        ':ULX3S',
        '//hdl/examples:Blinky',
        '//hdl/examples:UARTLoopback',
    ])

# Blinky design targets

yosys_design('blinky',
    top_module = 'mkBlinky',
    sources = [
        ':examples#mkBlinky',
    ],
    deps = [
        ':examples',
    ])

nextpnr_bitstream('blinky_ulx3s',
    env = 'ulx3s',
    design = ':blinky#json',
    deps = [
        ':blinky',
    ])

# UART loopback design targets

yosys_design('uart_loopback',
    top_module = 'mkUARTLoopback',
    sources = [
        ':examples#mkUARTLoopback',
        # TODO (arjen): make adding required Verilog modules portable.
        '/opt/bluespec/lib/Verilog/FIFO1.v',
    ],
    deps = [
        ':examples',
    ])

nextpnr_bitstream('uart_loopback_ulx3s',
    env = 'ulx3s',
    design = ':uart_loopback#json',
    deps = [
        ':uart_loopback',
    ])
