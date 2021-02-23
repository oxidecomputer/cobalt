# Copyright 2020 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import cobble.env
from cobble.plugin import *


BIN = cobble.env.overrideable_string_key('cat',
        default = 'cat',
        help = 'Path of cat binary.')
FLAGS = cobble.env.appending_string_seq_key('cat_flags',
        help = 'Extra flags to pass to cat.')

KEYS = frozenset([BIN, FLAGS])
_keys = frozenset([BIN.name, FLAGS.name])


@target_def
def cat(package, name, *,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    def mkusing(ctx):
        env = ctx.env.subset_require(_keys)
        output = package.outpath(env, name)
        product = cobble.target.Product(
            env = env,
            inputs = sources,
            outputs = [output],
            rule = 'cat')
        product.expose(path = output, name = 'out')

        return (using, [product])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )


ninja_rules = {
    'cat': {
        'command': '$cat $cat_flags $in > $out',
        'description': 'CAT $out',
    }
}
