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
        'mkLoopbackUART',
    ],
    deps = [
        ':Board',
        '//hdl/examples:Blinky',
        '//hdl/examples:LoopbackUART',
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

yosys_design('loopback_uart',
    top_module = 'mkLoopbackUART',
    sources = [
        ':examples#mkLoopbackUART',
        '//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':examples',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ice40_bitstream('loopback_uart_icestick',
    env = 'icestick',
    design = ':loopback_uart#loopback_uart.json',
    deps = [
        ':loopback_uart',
    ])
