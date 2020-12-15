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
    ],
    deps = [
        ':TestUtils'
    ])

bluespec_library('TestUtils',
    sources = [
        'TestUtils.bsv',
    ])

bluespec_simulation('fractional_strobe_test',
    env = 'default',
    top = 'Strobe.bsv',
    module = 'mkFractionalStrobeTest',
    deps = [
        ':Strobe',
    ])
