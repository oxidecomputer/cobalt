# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import cobble.env
from cobble.plugin import *
from cobble.git_version import *

GEN_GIT_VERSION_BSV = cobble.env.overrideable_string_key('gen_git_version_bsv',
          help = 'Path of version script')

KEYS = frozenset([GEN_GIT_VERSION_BSV])

_ver_keys = frozenset([GEN_GIT_VERSION_BSV.name, GIT_VERSION_CODE.name, GIT_VERSION_REV_SHA1_SHORT.name])


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
            rule = 'gen_git_version_bsv')

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
    'gen_git_version_bsv': {
        'command': ' python3 $gen_git_version_bsv $git_version_code $git_version_rev_sha1_short $out > $out',
        'description': 'gen_git_version_bsv.py $out',
    }
}
