# -*- python -*- vim:syntax=python:

bluespec_library('video',
    sources = [
        'TestPatternGenerator.bsv',
        'Timing.bsv',
        'Transmitter.bsv',
        'TMDS.bsv',
    ],
    deps = [
        '//hdl:TestUtils',
    ])

c_library('source_validation',
    sources = [
        'video_source_validation.cc',
    ])

bluesim_tests('TimingTests',
    env = 'bluesim_default',
    suite = 'Timing.bsv',
    modules = [
        'mkMinimalDisplayTimingTest',
        'mk100pDisplayTimingTest',
    ],
    deps = [
        ':video',
    ])

bluesim_tests('TestPatternGeneratorTests',
    env = 'bluesim_default',
    suite = 'TestPatternGenerator.bsv',
    modules = [
        'mkTestPatternGeneratorTest',
    ],
    deps = [
        ':video',
    ])

bluesim_tests('TMDSTests',
    env = 'bluesim_default',
    suite = 'TMDS.bsv',
    modules = [
        'mkEncoderTest',
    ],
    deps = [
        ':video',
    ])
