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
