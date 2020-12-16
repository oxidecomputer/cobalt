# Copyright 2020 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


import cobble.env
from cobble.plugin import *


NEXTPNR = cobble.env.overrideable_string_key('nextpnr',
        help = 'Path to the nextpnr binary.')
FLAGS = cobble.env.appending_string_seq_key('nextpnr_flags',
        help = 'Extra flags to pass to nextpnr.')
CONSTRAINTS = cobble.env.overrideable_string_key('nextpnr_constraints',
        help = 'Path to contraints file.')
PACK = cobble.env.overrideable_string_key('nextpnr_pack',
        help = 'Path to the bitstream packing binary.')
PACK_FLAGS = cobble.env.appending_string_seq_key('nextpnr_pack_flags',
        help = 'Extra flags to pass to pack binary.')

KEYS = frozenset([NEXTPNR, FLAGS, CONSTRAINTS, PACK, PACK_FLAGS])

_pnr_keys = frozenset([NEXTPNR.name, FLAGS.name, CONSTRAINTS.name])
_pack_keys = frozenset([PACK.name, PACK_FLAGS.name])


@target_def
def nextpnr_bitstream(package, name, *,
        env,
        design,
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    def mkusing(ctx):
        # Place and route design and produce a device configuration file in text format.
        config_env = ctx.env.subset_require(_pnr_keys)
        config = cobble.target.Product(
            env = config_env,
            inputs = ctx.rewrite_sources([design]),
            outputs = [package.outpath(config_env, name + '.config')],
            implicit = [ctx.env[CONSTRAINTS.name]],
            rule = 'place_and_route_ecp5_design',
        )

        # Pack device configuration file into a bitstream.
        bitstream_env = ctx.env.subset_require(_pack_keys)
        bitstream_out = name + '.bit'
        bitstream = cobble.target.Product(
            env = bitstream_env,
            inputs = config.outputs,
            outputs = [package.outpath(bitstream_env, bitstream_out)],
            symlink_as = package.linkpath(bitstream_out),
            rule = 'pack_ecp5_bitstream',
        )

        return (extra, [config, bitstream])

    return cobble.target.Target(
        package = package,
        name = name,
        concrete = True,
        down = lambda _up_unused: package.project.named_envs[env].derive(extra),
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )

ninja_rules = {
    'place_and_route_ecp5_design': {
        'command': '$nextpnr $nextpnr_flags -l $out.log --lpf $nextpnr_constraints --json $in --textcfg $out',
        'description': 'PNR $in',
    },
    'pack_ecp5_bitstream': {
        'command': '$nextpnr_pack $in $out $nextpnr_pack_flags',
        'description': 'PACK $in',
    }
}
