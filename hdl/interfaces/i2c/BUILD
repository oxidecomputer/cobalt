# -*- python -*- vim:syntax=python:

bluespec_library('i2c_core_regs',
    sources = [
        './i2c_core_regs/I2cCoreRegs.bsv',
    ])

bluespec_library('I2c',
    sources = [
        'I2c.bsv',
    ],
    deps = [
        ':i2c_core_regs',
    ])

bluespec_sim('i2c_tests',
    top = 'I2c_test.bsv',
    modules = [
        'mkI2cWriteTest',
    ],
    deps = [
        ':I2c',
    ])

bluesim_binary('i2c_basic_test',
    env = 'bluesim_default',
    top = ':i2c_tests#mkI2CTest',
    deps = [
        ':i2c_tests',
    ])