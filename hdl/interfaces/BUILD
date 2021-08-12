# -*- python -*- vim:syntax=python:

bluespec_library('ECP5',
    sources = [
        'ECP5.bsv',
    ],
    deps = [
        '//hdl:PLL',
    ])

#
# UART package and unit tests.
#

bluespec_library('UART',
    sources = [
        'UART.bsv',
    ],
    deps = [
        '//hdl:BitSampling',
        '//hdl:Strobe',
        '//hdl:TestUtils',
    ])

bluespec_sim('uart_tests',
    top = 'UART.bsv',
    modules = [
        'mkSerializerTest',
        'mkSerDesTest',
    ],
    deps = [
        ':UART'
    ])

bluesim_binary('uart_serializer_test',
    env = 'bluesim_default',
    top = ':uart_tests#mkSerializerTest',
    deps = [
        ':uart_tests',
    ])

bluesim_binary('uart_serdes_test',
    env = 'bluesim_default',
    top = ':uart_tests#mkSerDesTest',
    deps = [
        ':uart_tests',
    ])
