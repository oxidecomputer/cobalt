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

#
# Test Pattern Video Source
#

bluespec_library('TestPatternVideoSource',
    sources = [
        'TestPatternVideoSource.bsv',
    ],
    deps = [
        '//hdl/interfaces/video:video',
    ])

bluespec_verilog('TestPatternVideoSource_verilog',
    top = 'TestPatternVideoSource.bsv',
    modules = [
        'mk100pTestPatternVideoSource',
        'mk480pTestPatternVideoSource',
    ],
    deps = [
        ':TestPatternVideoSource',
    ])

yosys_design('mk100pTestPatternVideoSource',
    top_module = 'mk100pTestPatternVideoSource',
    sources = [
        ':TestPatternVideoSource_verilog#mk100pTestPatternVideoSource',
    ],
    deps = [
        ':TestPatternVideoSource_verilog',
    ])

c_binary('test_pattern_video_source',
    env = 'cxxrtl_default',
    sources = [
        'test_pattern_video_source.cc',
        ':mk100pTestPatternVideoSource#mk100pTestPatternVideoSource.cc',
    ],
    deps = [
        ':mk100pTestPatternVideoSource',
        '//hdl/interfaces/video:source_validation',
        '//vnd/yosys:cxxrtl',
    ])
