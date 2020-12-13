# -*- python -*- vim:syntax=python:

bluespec_library('ULX3S',
    sources = [
        'ULX3S.bsv',
    ],
    deps = [
        '//hdl/interfaces:ECP5',
    ])

bluespec_verilog('mkBlinky',
    top = 'ULX3S.bsv',
    output = 'mkBlinky.v',
    deps = [
        '//hdl/interfaces:ECP5',
    ])

yosys_design('blinky',
    top_module = 'mkBlinky',
    sources = [
        ':mkBlinky#mkBlinky.v',
    ],
    deps = [
        ':mkBlinky',
    ])

nextpnr_bitstream('blinky_ulx3s',
    env = 'ulx3s',
    design = ':blinky#json',
    deps = [
        ':blinky',
    ])
