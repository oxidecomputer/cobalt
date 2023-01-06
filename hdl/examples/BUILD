# -*- python -*- vim:syntax=python:

bluespec_library('Blinky',
    sources = [
        'Blinky.bsv',
    ])

bluespec_library('LoopbackUART',
    sources = [
        'LoopbackUART.bsv',
    ],
    deps = [
        '//hdl/interfaces:UART',
    ])

bluesim_tests('LoopbackUARTTests',
    env = 'bluesim_default',
    suite = 'LoopbackUART.bsv',
    modules = [
        'mkLoopbackUARTTest',
    ],
    deps = [
        ':LoopbackUART',
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
