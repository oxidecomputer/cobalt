# -*- python -*- vim:syntax=python:

bluespec_library('BitSampling',
    sources = [
        'BitSampling.bsv',
    ],
    deps = [
        ':Strobe',
    ])

bluespec_library('Encoding8b10b',
    sources = [
        'Encoding8b10b.bsv',
        'Encoder8b10b.bsv',
        'Decoder8b10b.bsv',
    ],
    deps = [
        ':BitSampling',
        ':TestUtils',
    ])

bluespec_library('Strobe',
    sources = [
        'Strobe.bsv'
    ])

bluespec_library('TestUtils',
    sources = [
        'TestUtils.bsv',
    ])

# Tests

def test_module(name, library, top, module):
    object_dep = name + '_object'
    bluespec_sim(object_dep,
        top = top,
        modules = [
            module,
        ],
        deps = [
            ':' + library,
        ])
    bluesim_binary(name,
        env = 'bluesim_default',
        top = ':%s#%s' % (object_dep, module),
        deps = [
            ':' + object_dep,
        ])

test_module('fractional_strobe_test', 'Strobe', 'Strobe.bsv', 'mkFractionalStrobeTest')
