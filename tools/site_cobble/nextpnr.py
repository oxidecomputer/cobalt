# Copyright 2020 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


import cobble.env
from cobble.plugin import *


CONSTRAINTS = cobble.env.overrideable_string_key('nextpnr_constraints',
        help = 'Path to contraints file for nextpnr.')

NEXTPNR_ECP5 = cobble.env.overrideable_string_key('nextpnr_ecp5',
        help = 'Path to the nextpnr-ecp5 binary.')
FLAGS_ECP5 = cobble.env.appending_string_seq_key('nextpnr_ecp5_flags',
        help = 'Extra flags to pass to nextpnr-ecp5.')
PACK_ECP5 = cobble.env.overrideable_string_key('nextpnr_ecp5_pack',
        help = 'Path to the bitstream packing binary for ECP5.')
PACK_FLAGS_ECP5 = cobble.env.appending_string_seq_key('nextpnr_ecp5_pack_flags',
        help = 'Extra flags to pass to ECP5 pack binary.')


KEYS = frozenset([
    CONSTRAINTS,
    NEXTPNR_ECP5, FLAGS_ECP5, PACK_ECP5, PACK_FLAGS_ECP5,
])

_pnr_ecp5_keys = frozenset([
    NEXTPNR_ECP5.name, FLAGS_ECP5.name, CONSTRAINTS.name,
])
_pack_ecp5_keys = frozenset([PACK_ECP5.name, PACK_FLAGS_ECP5.name])

_known_families = frozenset(["ecp5"])

def _any_bitstream(package, name, *,
        nextpnr_family_name,
        pnr_keys,
        pack_keys,
        env,
        design,
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    if not nextpnr_family_name in _known_families:
        raise AssertError("Unknown nextpnr family: " + nextpnr_family_name)

    def mkusing(ctx):
        # Place and route design and produce a device configuration file in text format.
        config_env = ctx.env.subset_require(pnr_keys)
        config = cobble.target.Product(
            env = config_env,
            inputs = ctx.rewrite_sources([design]),
            outputs = [package.outpath(config_env, name + '.config')],
            implicit = [ctx.env[CONSTRAINTS.name]],
            rule = 'place_and_route_' + nextpnr_family_name + '_design',
        )

        # Pack device configuration file into a bitstream.
        bitstream_env = ctx.env.subset_require(pack_keys)
        bitstream_out = name + '.bit'
        bitstream_path = package.outpath(bitstream_env, bitstream_out)
        bitstream = cobble.target.Product(
            env = bitstream_env,
            inputs = config.outputs,
            outputs = [bitstream_path],
            rule = 'pack_' + nextpnr_family_name + '_bitstream',
        )
        bitstream.symlink(
            target = bitstream_path,
            source = package.linkpath(bitstream_out))

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

@target_def
def nextpnr_ecp5_bitstream(package, name, *,
        env,
        design,
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    return _any_bitstream(package, name,
            env = env,
            design = design,
            deps = deps,
            local = local,
            extra = extra,
            nextpnr_family_name = "ecp5",
            pnr_keys = _pnr_ecp5_keys,
            pack_keys = _pack_ecp5_keys,
    )

ninja_rules = {
    'place_and_route_ecp5_design': {
        'command': '$nextpnr_ecp5 $nextpnr_ecp5_flags -l $out.log --lpf $nextpnr_constraints --json $in --textcfg $out',
        'description': 'PNR(ECP5) $in',
    },
    'pack_ecp5_bitstream': {
        'command': '$nextpnr_ecp5_pack $in $out $nextpnr_ecp5_pack_flags',
        'description': 'PACK(ECP5) $in',
    },
}
