# Copyright 2021 Oxide Computer Company
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

NEXTPNR_ICE40 = cobble.env.overrideable_string_key('nextpnr_ice40',
        help = 'Path to the nextpnr-ice40 binary.')
FLAGS_ICE40 = cobble.env.appending_string_seq_key('nextpnr_ice40_flags',
        help = 'Extra flags to pass to nextpnr-ice40.')
PACK_ICE40 = cobble.env.overrideable_string_key('nextpnr_ice40_pack',
        help = 'Path to the bitstream packing binary for ICE40.')
PACK_FLAGS_ICE40 = cobble.env.appending_string_seq_key('nextpnr_ice40_pack_flags',
        help = 'Extra flags to pass to ICE40 pack binary.')

KEYS = frozenset([
    CONSTRAINTS,
    NEXTPNR_ECP5, FLAGS_ECP5, PACK_ECP5, PACK_FLAGS_ECP5,
    NEXTPNR_ICE40, FLAGS_ICE40, PACK_ICE40, PACK_FLAGS_ICE40,
])

_pnr_ecp5_keys = frozenset([
    NEXTPNR_ECP5.name, FLAGS_ECP5.name, CONSTRAINTS.name,
])
_pack_ecp5_keys = frozenset([PACK_ECP5.name, PACK_FLAGS_ECP5.name])

_pnr_ice40_keys = frozenset([
    NEXTPNR_ICE40.name, FLAGS_ICE40.name, CONSTRAINTS.name,
])
_pack_ice40_keys = frozenset([PACK_ICE40.name, PACK_FLAGS_ICE40.name])

_known_families = frozenset(["ecp5", "ice40"])

def _any_bitstream(package, name, *,
        nextpnr_family_name,
        pnr_keys,
        pack_keys,
        flag_key,
        env,
        design,
        pre_pack = [],
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    if not nextpnr_family_name in _known_families:
        raise AssertError("Unknown nextpnr family: " + nextpnr_family_name)

    def mkusing(ctx):
        # Place and route design and produce a device configuration file in text format.
        pps = ctx.rewrite_sources(pre_pack)
        config_env = ctx.env.subset_require(pnr_keys).derive({
            flag_key.name: ["--pre-pack " + s for s in pps],
        })
        config_path = package.outpath(config_env, name + '.config')
        log_path = config_path + '.log'
        config = cobble.target.Product(
            env = config_env,
            inputs = ctx.rewrite_sources([design]),
            outputs = ([config_path], [log_path]),
            implicit = [ctx.env[CONSTRAINTS.name]] + pps,
            rule = 'place_and_route_' + nextpnr_family_name + '_design',
        )
        config.expose(path = log_path, name = 'report')
        config_report_link = package.linkpath(name + '.report.txt')
        config.symlink(
            target = log_path,
            source = config_report_link)

        # Pack device configuration file into a bitstream.
        bitstream_env = ctx.env.subset_require(pack_keys)
        bitstream_out = name + '.bit'
        bitstream_path = package.outpath(bitstream_env, bitstream_out)
        bitstream = cobble.target.Product(
            env = bitstream_env,
            inputs = config.outputs,
            outputs = [bitstream_path],
            implicit = [config_report_link],
            rule = 'pack_' + nextpnr_family_name + '_bitstream',
        )
        bitstream.expose(path = bitstream_path, name = 'bitstream')
        bitstream.symlink(
            target = bitstream_path,
            source = package.linkpath(bitstream_out))

        return (extra, [config, bitstream])

    return cobble.target.Target(
        package = package,
        name = name,
        concrete = True,
        down = lambda _up_unused: \
            package.project.find_environment(env).derive(extra),
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )

@target_def
def nextpnr_ecp5_bitstream(package, name, *,
        env,
        design,
        deps = [],
        pre_pack = [],
        local: Delta = {},
        extra: Delta = {}):
    return _any_bitstream(package, name,
            env = env,
            design = design,
            deps = deps,
            pre_pack = pre_pack,
            local = local,
            extra = extra,
            nextpnr_family_name = "ecp5",
            pnr_keys = _pnr_ecp5_keys,
            pack_keys = _pack_ecp5_keys,
            flag_key = FLAGS_ECP5,
    )

@target_def
def nextpnr_ice40_bitstream(package, name, *,
        env,
        design,
        deps = [],
        pre_pack = [],
        local: Delta = {},
        extra: Delta = {}):
    return _any_bitstream(package, name,
            env = env,
            design = design,
            deps = deps,
            pre_pack = pre_pack,
            local = local,
            extra = extra,
            nextpnr_family_name = "ice40",
            pnr_keys = _pnr_ice40_keys,
            pack_keys = _pack_ice40_keys,
            flag_key = FLAGS_ICE40,
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
    'place_and_route_ice40_design': {
        'command': '$nextpnr_ice40 $nextpnr_ice40_flags -l $out.log --pcf $nextpnr_constraints --json $in --asc $out',
        'description': 'PNR(iCE40) $in',
    },
    'pack_ice40_bitstream': {
        'command': '$nextpnr_ice40_pack $in $out $nextpnr_ice40_pack_flags',
        'description': 'PACK(iCE40) $in',
    },
}
