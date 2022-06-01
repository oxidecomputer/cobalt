# -*- python -*- vim:syntax=python:

bluespec_library('RegCommon',
    sources = [
        './i2c_core_regs/RegCommon.bsv',
    ])

bluespec_library('I2cCoreRegs',
    sources = [
        './i2c_core_regs/I2cCoreRegs.bsv',
    ],
    deps = [
        ':RegCommon',
    ])

bluespec_library('Strobe',
    sources = [
        '../../Strobe.bsv'
    ])

bluespec_library('I2c',
    sources = [
        'I2c.bsv',
    ],
    deps = [
        ':I2cCoreRegs',
        ':Strobe'
    ])

bluesim_tests('I2cTests',
    env = 'bluesim_default',
    suite = 'I2cTest.bsv',
    modules = [
        'mkI2cBitControlOneByteWriteTest',
        'mkI2cBitControlOneByteReadTest',
        'mkI2cBitControlSequentialWriteTest',
        'mkI2cBitControlSequentialReadTest',
        'mkI2cBitControlRandomReadTest',
    ],
    deps = [
        ':I2c',
    ])