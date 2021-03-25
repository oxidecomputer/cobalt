# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import cobble.env
from cobble.plugin import *


CAT_BIN = cobble.env.overrideable_string_key('shell_cat',
        default = 'cat',
        help = 'Path of cat binary.')
CAT_FLAGS = cobble.env.appending_string_seq_key('shell_cat_flags',
        help = 'Extra flags to pass to cat.')

KEYS = frozenset([CAT_BIN, CAT_FLAGS])

_cat_keys = frozenset([CAT_BIN.name, CAT_FLAGS.name])


@target_def
def shell_cat(package, name, *,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    def mkusing(ctx):
        env = ctx.env.subset_require(_cat_keys)
        output = package.outpath(env, name)
        product = cobble.target.Product(
            env = env,
            inputs = sources,
            outputs = [output],
            rule = 'shell_cat')

        product.expose(path = output, name = name)
        return (using, [product])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )


ninja_rules = {
    'shell_cat': {
        'command': '$shell_cat $shell_cat_flags $in > $out',
        'description': 'CAT $out',
    }
}
