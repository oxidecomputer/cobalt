# -*- python -*- vim:syntax=python:

bluespec_library('ECP5',
    sources = [
        'ECP5.bsv',
    ])

bluespec_library('UART',
    sources = [
        'UART.bsv',
    ],
    deps = [
        '//hdl:BitSampling',
        '//hdl:Strobe',
        '//hdl:TestUtils',
    ])

bluespec_simulation('uart_serdes_test',
    env = 'default',
    top = 'UART.bsv',
    module = 'mkSerDesTest',
    deps = [
        '//hdl:BitSampling',
        '//hdl:Strobe',
        '//hdl:TestUtils',
    ])
