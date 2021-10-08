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

bluespec_library('PLL',
    sources = [
        'PLL.bsv'
    ])

bluespec_library('SchmittReg',
    sources = [
        'SchmittReg.bsv'
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

def test_module(name, library, module):
    object_dep = name + '_object'
    bluespec_sim(object_dep,
        top = library + '.bsv',
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

test_module('fractional_strobe_test', 'Strobe', 'mkFractionalStrobeTest')

test_module('fast_edge_schmitt_reg_test', 'SchmittReg', 'mkFastEdgeSchmittRegTest')
test_module('long_bounce_schmitt_reg_test', 'SchmittReg', 'mkLongBounceSchmittRegTest')
