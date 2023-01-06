# -*- python -*- vim:syntax=python:

bluespec_library('ECP5',
    sources = [
        'ECP5.bsv',
    ],
    deps = [
        '//hdl:PLL',
    ])

bluespec_library('ICE40',
    sources = [
        'ICE40.bsv',
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
        '//hdl:SerialIO',
        '//hdl:Strobe',
        '//hdl:TestUtils',
    ])

bluesim_tests('UARTTests',
    env = 'bluesim_default',
    suite = 'UART.bsv',
    modules = [
        'mkSerializerTest',
        'mkDeserializerTest',
        'mkDeserializerStopMissingTest',
        'mkDeserializerOverflowTest',
        'mkSerializerDeserializerTest',
    ],
    deps = [
        ':UART',
    ])

#
# SPI package and unit tests.
#

bluespec_library('SPI',
    sources = [
        'SPI.bsv',
    ],
    deps = [
        '//hdl:RegCommon',
    ])

bluesim_tests('SPITests',
    env = 'bluesim_default',
    suite = 'SPI.bsv',
    modules = [
        'mkSpiDecodeTest',
        'mkSpiPhyTest',
    ],
    deps = [
        ':SPI',
    ])
