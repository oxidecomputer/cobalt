# -*- python -*- vim:syntax=python:

bluespec_library('Blinky',
    sources = [
        'Blinky.bsv',
    ])

bluespec_library('UARTLoopback',
    sources = [
        'UARTLoopback.bsv',
    ],
    deps = [
        '//hdl/interfaces:UART',
    ])

bluespec_sim('loopback_tests',
    top = 'UARTLoopback.bsv',
    modules = [
        'mkUARTLoopbackTest'
    ],
    deps = [
        ':UARTLoopback',
    ])

bluesim_binary('uart_loopback_test',
    env = 'bluesim_default',
    top = ':loopback_tests#mkUARTLoopbackTest',
    deps = [
        ':loopback_tests',
    ])
