# -*- python -*- vim:syntax=python:

bluespec_library('Encoding8b10bTest',
    sources = [
        'Encoding8b10bTest.bsv',
    ],
    deps = [
        '//hdl:Encoding8b10b',
        '//hdl:TestUtils',
    ])

bluespec_sim('encoding8b10b_tests',
    top = 'Encoding8b10bTest.bsv',
    modules = [
        'mkConnectTest',
        'mkDisconnectTest',
    ],
    deps = [
        ':Encoding8b10bTest',
    ])

def encoding8b10b_test(name, module):
    bluesim_binary('8b10b_' + name,
        env = 'bluesim_default',
        top = ':encoding8b10b_tests#%s' % module,
        deps = [
            ':encoding8b10b_tests',
        ])

encoding8b10b_test('serdes_connect_test', 'mkConnectTest')
encoding8b10b_test('serdes_disconnect_test', 'mkDisconnectTest')
