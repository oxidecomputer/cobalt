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
BACKEND_FLAGS = cobble.env.appending_string_seq_key('yosys_backend_flags',
        help = ('Additional flags passed to the Yosys backend when writing the output.'
                'Note: this is currently not implemented.'),
        readout = lambda fs: ' '.join(fs))

KEYS = frozenset([YOSYS, AWK, FLAGS, CMDS, BACKEND, BACKEND_FLAGS])
_keys = frozenset([YOSYS.name, AWK.name, FLAGS.name, BACKEND.name, BACKEND_FLAGS.name])


@target_def
def yosys_design(package, name, *,
        top_module,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    def mkusing(ctx):
        out = '%s.%s' % (name, ctx.env[BACKEND.name])
        _sources = ctx.rewrite_sources(sources)

        read_cmds = _read_sources(_sources)

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
        env = ctx.env.subset_require(_keys).without([CMDS.name]).derive({
            CMDS.name: read_cmds + cmds,
        })

        script_path = package.outpath(env, out + '.ys')
        script = cobble.target.Product(
            env = env,
            outputs = [script_path],
            rule = 'yosys_script')

        design_path = package.outpath(env, out)
        design = cobble.target.Product(
            env = env,
            inputs = _sources,
            outputs = [design_path],
            implicit = [script_path],
            rule = 'yosys_design')
        design.expose(path = design_path, name = ctx.env[BACKEND.name])

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

def _read_sources(sources):
    read_cmds = []
    for path in sources:
        ext = os.path.splitext(path)[1]
        cmd_with_args = _read_cmd_file_type_map[ext]
        read_cmds.append(' '.join(cmd_with_args) + ' ' + path)
    return read_cmds


ninja_rules = {
    'yosys_script': {
        'command': '$yosys_awk \'$$1=$$1\' RS=\';\' $out.rsp > $out',
        'description': 'RSP $out',
        'rspfile': '$out.rsp',
        'rspfile_content': '$yosys_cmds',
    },
    'yosys_design': {
        'command': '$yosys $yosys_flags -q -L $out.log -s $out.ys -b $yosys_backend -o $out',
        'description': 'YOSYS $out.ys',
    }
}
