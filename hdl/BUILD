# -*- python -*- vim:syntax=python:

# FPGA Version package
bsv_fpga_version('git_version',
)

bluespec_library('GitVersion',
    sources = [
       ':git_version#git_version.bsv',
    ],
    deps = [
        ':git_version'
    ]
)

# Common support scaffolding
bluespec_library('RegCommon',
    sources = [
       'RegCommon.bsv',
    ],
)

# Cobalt modules
bluespec_library('Bidirection',
    sources = [
        'Bidirection.bsv',
    ])

bluespec_library('BitSampling',
    sources = [
        'BitSampling.bsv',
    ],
    deps = [
        ':Strobe',
    ])

bluespec_library('Countdown',
    sources = [
        'Countdown.bsv',
    ])

bluespec_library('Debouncer',
    sources = [
        'Debouncer.bsv',
    ],
    deps = [
        ':TestUtils',
    ])

bluespec_library('Encoding8b10b',
    sources = [
        'Deserializer8b10b.bsv',
        'Encoding8b10b.bsv',
        'Serializer8b10b.bsv',
    ])

bluespec_library('InitialReset',
    sources = [
        'InitialReset.bsv',
    ],
    deps = [
        ':TestUtils',
    ])

bluespec_library('IOSync',
    sources = [
        'IOSync.bsv',
    ],
    deps = [
        ':Bidirection',
        ':WriteOnlyTriState',
    ])

bluespec_library('PLL',
    sources = [
        'PLL.bsv'
    ])

bluespec_library('SchmittReg',
    sources = [
        'SchmittReg.bsv'
    ])

bluespec_library('SerialIO',
    sources = [
        'SerialIO.bsv'
    ],
    deps = [
        ':BitSampling',
        ':IOSync',
        ':Strobe',
        ':WriteOnlyTriState',
    ])

bluespec_library('Strobe',
    sources = [
        'Strobe.bsv'
    ])

bluespec_library('SyncBits',
    sources = [
        'SyncBits.bsv',
    ])

bluespec_library('TestUtils',
    sources = [
        'TestUtils.bsv',
    ])

bluespec_library('WriteOnceReg',
    sources = [
        'WriteOnceReg.bsv',
    ])

bluespec_library('WriteOnlyTriState',
    sources = [
        'WriteOnlyTriState.bsv',
    ])

# Tests

bluesim_tests('CountdownTest',
    env = 'bluesim_default',
    suite = 'Countdown.bsv',
    modules = [
        'mkCountdownTest',
    ],
    deps = [
        ':Countdown',
    ])

bluesim_tests('DebouncerTest',
    env = 'bluesim_default',
    suite = 'Debouncer.bsv',
    modules = [
        'mkDebouncerTest',
        'mkDebounceFastAssertTest',
        'mkDebounceFastDeassertTest',
    ],
    deps = [
        ':Debouncer',
        ':TestUtils',
    ])

bluesim_tests('InitialResetTests',
    env = 'bluesim_default',
    suite = 'InitialReset.bsv',
    modules = [
        'mkInitialResetTest',
    ],
    deps = [
        ':InitialReset',
    ])

bluesim_tests('SchmittRegTests',
    env = 'bluesim_default',
    suite = 'SchmittReg.bsv',
    modules = [
        'mkSlowEdgeSchmittRegTest',
        'mkFastPositiveEdgeSchmittRegTest',
        'mkLongBounceSchmittRegTest',
    ])

bluesim_tests('StrobeTests',
    env = 'bluesim_default',
    suite = 'Strobe.bsv',
    modules = [
        'mkPowerTwoStrobeTest',
        'mkPowerTwoStrobeAsCountDownTest',
        'mkFractionalStrobeTest',
        'mkLimitStrobeStrobeTest',
    ])
