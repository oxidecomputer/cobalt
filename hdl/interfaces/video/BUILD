def bluesim_test(name, top, module):
    bluesim_binary(name,
        env = 'bluesim_default',
        top = ':%s#%s' % (top, module),
        deps = [
            ':%s' % top,
        ])

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

#
# BlueSim targets
#

bluespec_sim('Timing_tests',
    top = 'Timing.bsv',
    modules = [
        'mkMinimalDisplayTimingTest',
        'mk100pDisplayTimingTest',
    ],
    deps = [
        ':video',
    ])

bluespec_sim('TestPatternGenerator_tests',
    top = 'TestPatternGenerator.bsv',
    modules = [
        'mkTestPatternGeneratorTest',
    ],
    deps = [
        ':video',
    ])

bluespec_sim('TMDS_tests',
    top = 'TMDS.bsv',
    modules = [
        'mkEncoderTest',
    ],
    deps = [
        ':video',
    ])

#
# Runnable tests
#

bluesim_test('minimal_display_timing_test', 'Timing_tests', 'mkMinimalDisplayTimingTest')
bluesim_test('100p_display_timing_test', 'Timing_tests', 'mk100pDisplayTimingTest')

bluesim_test(
    'test_pattern_generator_test',
    'TestPatternGenerator_tests',
    'mkTestPatternGeneratorTest')

bluesim_test('tmds_encoder_test', 'TMDS_tests', 'mkEncoderTest')
