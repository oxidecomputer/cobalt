# -*- python -*- vim:syntax=python:

bluespec_library('UARTLoopback',
    sources = [
        'UARTLoopback.bsv',
    ],
    deps = [
        '//hdl/interfaces:UART',
    ])

bluespec_simulation('uart_loopback_test',
    env = 'default',
    top = 'UARTLoopback.bsv',
    module = 'mkUARTLoopbackTest',
    deps = [
        ':UARTLoopback',
    ])
