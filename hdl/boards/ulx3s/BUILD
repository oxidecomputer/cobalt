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

nextpnr_ecp5_bitstream('blinky_ulx3s',
    env = 'ulx3s',
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

nextpnr_ecp5_bitstream('uart_loopback_ulx3s',
    env = 'ulx3s',
    design = ':uart_loopback#uart_loopback.json',
    deps = [
        ':uart_loopback',
    ])

# UInt16 Sampler design targets

bluespec_verilog('UInt16Sampler',
    top = 'UInt16Sampler.bsv',
    modules = [
        'mkUInt16Sampler',
    ],
    deps = [
        ':Board',
        '//hdl:InitialReset',
        '//hdl/interfaces:UART',
        '//hdl/test:UInt16SamplingMemory',
    ])

yosys_design('uint16_sampler',
    top_module = 'mkUInt16Sampler',
    sources = [
        ':UInt16Sampler#mkUInt16Sampler',
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../InitialReset.v',
    ],
    deps = [
        ':UInt16Sampler',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('uint16_sampler_ulx3s',
    env = 'ulx3s',
    design = ':uint16_sampler#uint16_sampler.json',
    deps = [
        ':uint16_sampler',
    ])
