# -*- python -*- vim:syntax=python:

bluespec_library('Board',
    sources = [
        'Board.bsv',
    ],
    deps = [
        '//hdl/interfaces:ECP5',
    ])

bluespec_verilog('examples',
    top = 'Examples.bsv',
    modules = [
        'mkBlinky',
        'mkLoopbackUART',
    ],
    deps = [
        ':Board',
        '//hdl:IOSync',
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

nextpnr_ecp5_bitstream('blinky_ulx3s',
    env = 'ulx3s',
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

nextpnr_ecp5_bitstream('loopback_uart_ulx3s',
    env = 'ulx3s',
    design = ':loopback_uart#loopback_uart.json',
    deps = [
        ':loopback_uart',
    ])
