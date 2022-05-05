# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


import string
import os.path

import cobble.env
from cobble.plugin import *


YOSYS = cobble.env.overrideable_string_key('yosys',
        default = 'yosys',
        help = 'Name/path of Yosys binary.')
AWK = cobble.env.overrideable_string_key('yosys_awk',
        default = 'awk',
        help = 'Name/path of the AWK binary used to generate the Yosys script.')
FLAGS = cobble.env.appending_string_seq_key('yosys_flags',
        help = 'Extra flags to pass to Yosys.')

CMDS = cobble.env.appending_string_seq_key('yosys_cmds',
        help = 'Commands used by Yosys for processing the design.',
        readout = lambda cs: ';'.join(cs))
BACKEND = cobble.env.overrideable_string_key('yosys_backend',
        help = 'Backend used by Yosys to write the output result.')

SCRIPT = cobble.env.overrideable_string_key('yosys_script',
        help = 'Internel key used to pass the path to a script file')

KEYS = frozenset([YOSYS, AWK, FLAGS, CMDS, BACKEND, SCRIPT])
_script_keys = frozenset([AWK.name, CMDS.name])
_design_keys = frozenset([YOSYS.name, FLAGS.name, BACKEND.name, SCRIPT.name])


@target_def
def yosys_design(package, name, *,
        top_module,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    # Free up name
    _using = using

    def mkusing(ctx):
        rewritten_sources = ctx.rewrite_sources(sources)
        read_cmds = _read_sources(rewritten_sources)

        # Yosys commands effectively represent another layer of variables and indirection which
        # needs to be resolved before a script can be written out using a Ninja rule. We want to
        # intercept and rewrite any commands here in order to do this.
        cmd_vars = {
            'top_module': top_module,
        }

        cmds = [
            string.Template(cmd).substitute(cmd_vars)
            for cmd
            in ctx.env[CMDS.name].split(';')
        ]

        # Generate a new environment with commands replaced by their interpolated versions as any
        # required reads.
        script_env = ctx.env.subset_require(_script_keys).without([CMDS.name]).derive({
            CMDS.name: read_cmds + cmds,
        })

        script_path = package.outpath(script_env, name + '.ys')
        script = cobble.target.Product(
            env = script_env,
            outputs = [script_path],
            rule = 'yosys_generate_script')

        # With a Yosys script in hand, determine the resulting product.

        env = ctx.env.subset(_design_keys).derive({
            SCRIPT.name: script_path,
        })
        backend = ctx.env[BACKEND.name]
        backend_cmd = backend.split()[0]
        ext = _backend_file_type_map.get(backend_cmd, backend_cmd)

        # The primary output is determined by the backend...
        outputs = [package.outpath(env, '%s.%s' % (name, ext))]

        # but there may be additional implicit outputs.
        implicit_outputs = []
        if backend.startswith('cxxrtl') and '-header' in backend:
            implicit_outputs.append(package.outpath(env, '%s.h' % name))

        design = cobble.target.Product(
            env = env,
            inputs = rewritten_sources,
            outputs = (outputs, implicit_outputs),
            implicit = [script_path],
            rule = 'yosys_process_design')

        # Expose the outputs.
        design.expose(name = os.path.basename(outputs[0]), path = outputs[0])
        for path in design.implicit_outputs:
            design.expose(name = os.path.basename(path), path = path)

        # Extend the environment if a cxxrtl model was generated so it or its header file can be
        # included by a dependants.
        if backend.startswith('cxxrtl'):
            using = (
                _using,
                cobble.env.prepare_delta({
                    # Add the necessary include paths.
                    'cxx_flags': [
                        # Required for the generated .cc file to be able to include its .h file.
                        '-I%s' % package.project.build_dir,
                        # Required to have dependants include either the .h or
                        # .cc file.
                        #
                        # Note: it is important to use `Project.outpath(..)`
                        # here because this path changes depending on whether or
                        # not the project is the root or a subproject.
                        '-I%s' % package.project.outpath(env, ('')),
                    ],
                    # Anything using the generated .h or .cc file will want to include them. This
                    # forces the generation of these files to happen independent of the order in
                    # which the C files may be compiled.
                    '__order_only__': outputs + implicit_outputs,
                }),
            )
        else:
            using = _using

        return (using, [script, design])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )

_read_cmd_file_type_map = {
    '.v': ['read_verilog'],
    '.sv': ['read_verilog', '-sv'],
}
_backend_file_type_map = {
    'cxxrtl': 'cc',
}

def _read_sources(sources):
    read_cmds = []
    for path in sources:
        ext = os.path.splitext(path)[1]
        cmd_with_args = _read_cmd_file_type_map[ext]
        read_cmds.append(' '.join(cmd_with_args) + ' ' + path)
    return read_cmds


ninja_rules = {
    'yosys_generate_script': {
        'command': '$yosys_awk \'$$1=$$1\' RS=\';\' $out.rsp > $out',
        'description': 'RSP $out',
        'rspfile': '$out.rsp',
        'rspfile_content': '$yosys_cmds',
    },
    'yosys_process_design': {
        'command': '$yosys $yosys_flags -q -L $out.log -s $yosys_script -b "$yosys_backend" -o $out',
        'description': 'YOSYS $yosys_script',
    }
}
