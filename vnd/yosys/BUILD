INCLUDE_DIR = '%s/include' % VARS.get('yosys', 'libdir', default = '/usr/local/share/yosys')
CXX_FLAGS = {
    'cxx_flags': [
        '-I%s' % INCLUDE_DIR,
    ]}

c_library('cxxrtl',
    sources = [
        '%s/backends/cxxrtl/%s' % (INCLUDE_DIR, f)
        for f in [
            'cxxrtl_capi.cc',
            'cxxrtl_vcd_capi.cc',
        ]
    ],
    local = CXX_FLAGS,
    using = CXX_FLAGS,
)
