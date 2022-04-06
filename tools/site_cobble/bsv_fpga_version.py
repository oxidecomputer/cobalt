# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import cobble.env
from cobble.plugin import *
from cobble.git_version import *

GEN_VERSION_BSV = cobble.env.overrideable_string_key('gen_version_bsv',
          help = 'Path of version script')
#         default = 'cat',
#         help = 'Path of cat binary.')
# CAT_FLAGS = cobble.env.appending_string_seq_key('shell_cat_flags',
#         help = 'Extra flags to pass to cat.')

KEYS = frozenset([GEN_VERSION_BSV])

_ver_keys = frozenset([GEN_VERSION_BSV.name, GIT_VERSION_CODE.name, GIT_VERSION_REV_SHA1_SHORT.name])


@target_def
def bsv_fpga_version(package, name, *,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    def mkusing(ctx):
        env = ctx.env.subset_require(_ver_keys)
        bsv_name = name + '.bsv'
        output = package.outpath(env, bsv_name)
        product = cobble.target.Product(
            env = env,
            inputs = sources,
            outputs = [output],
            rule = 'gen_version_bsv')

        product.expose(path = output, name = bsv_name)
        return (using, [product])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )


ninja_rules = {
    'gen_version_bsv': {
        'command': ' python3 $gen_version_bsv $git_version_code $git_version_rev_sha1_short > $out',
        'description': 'gen_version_bsv.py $out',
    }
}
