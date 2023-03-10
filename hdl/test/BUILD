# -*- python -*- vim:syntax=python:

bluespec_library('Encoding8b10bReference',
    sources = [
        'Encoding8b10bReference.bsv',
    ],
    deps = [
        '//hdl:Encoding8b10b',
    ])

bluesim_tests('Encoding8b10bTests',
    env = 'bluesim_default',
    suite = 'Encoding8b10bTests.bsv',
    modules = [
        'mkEncodeTest',
        'mkEncodeDecodeTest',
    ],
    deps = [
        ':Encoding8b10bReference',
        '//hdl:Encoding8b10b',
        '//hdl:TestUtils',
    ])

bluesim_tests('BitSamplingTests',
    env = 'bluesim_default',
    suite = 'BitSamplingTests.bsv',
    modules = [
        'mkBitSampling2Test',
        'mkBitSampling3Test',
        'mkBitSampling4Test',
        'mkBitSampling5Test',
        'mkBitSampling8Test',
        'mkBitSampling16Test',
        'mkBitSampling3JitterTest',
        'mkBitSampling4JitterTest',
        'mkBitSampling5JitterTest',
        'mkBitSampling8JitterTest',
        'mkBitSampling16JitterTest',
        'mkAsyncBitSamplingTest',
    ],
    deps = [
        '//hdl:BitSampling',
        '//hdl:TestUtils',
    ])
