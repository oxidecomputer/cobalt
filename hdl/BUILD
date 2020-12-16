# -*- python -*- vim:syntax=python:

bluespec_library('BitSampling',
    sources = [
        'BitSampling.bsv',
    ],
    deps = [
        ':Strobe',
    ])

bluespec_library('Strobe',
    sources = [
        'Strobe.bsv'
    ])

bluespec_library('TestUtils',
    sources = [
        'TestUtils.bsv',
    ])

bluespec_sim('strobe_tests',
    top = 'Strobe.bsv',
    modules = [
        'mkFractionalStrobeTest',
    ],
    deps = [
        ':Strobe',
    ])

bluesim_binary('fractional_strobe_test',
    env = 'bluesim_default',
    top = ':strobe_tests#mkFractionalStrobeTest',
    deps = [
        ':strobe_tests',
    ])
