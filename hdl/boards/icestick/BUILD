# -*- python -*- vim:syntax=python:

bluespec_library('Board',
    sources = [
        'Board.bsv',
    ],
)

bluespec_verilog('examples',
    top = 'Examples.bsv',
    modules = [
        'mkBlinky',
        'mkUARTLoopback',
    ],
    deps = [
        ':Board',
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

nextpnr_ice40_bitstream('blinky_icestick',
    env = 'icestick',
    design = ':blinky#blinky.json',
    deps = [
        ':blinky',
    ])

# UART loopback design targets

yosys_design('uart_loopback',
    top_module = 'mkUARTLoopback',
    sources = [
        ':examples#mkUARTLoopback',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':examples',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('uart_loopback_icestick',
    env = 'icestick',
    design = ':uart_loopback#uart_loopback.json',
    deps = [
        ':uart_loopback',
    ])
