# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import inflection
from pathlib import Path

import cobble.env
from cobble.plugin import *
from cobble.git_version import *

RDL_SCRIPT = cobble.env.overrideable_string_key('rdl_script',
          help = 'Path of rdl script')

RDL_ODIR = cobble.env.overrideable_string_key('rdl_odir')

KEYS = frozenset([RDL_SCRIPT, RDL_ODIR])

_ver_keys = frozenset([RDL_SCRIPT.name])


def to_camel_case(template_string, uppercamel=False):
    return inflection.camelize(template_string, uppercase_first_letter=uppercamel)


def to_snake_case(template_string):
    return inflection.underscore(template_string)


@target_def
def rdl(package, name, *,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    
    def mkusing(ctx):
        sources_i = ctx.rewrite_sources(sources)
        env = ctx.env.subset_require(_ver_keys)
        out_dir = package.outpath(env)
        p_env = env.derive({
            RDL_ODIR.name:out_dir,
        })
        in_name = Path(sources_i[0]).stem
        bsv_name = f'{to_camel_case(in_name.lower(), uppercamel=True)}.bsv'
        output = package.outpath(env, bsv_name)
        product = cobble.target.Product(
            env = p_env,
            inputs = sources_i,
            outputs = [output],
            rule = 'rdl_script')

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
    'rdl_script': {
        'command': ' python3 $rdl_script $in --out-dir $rdl_odir',
        'description': 'making rdl outputs',
    }
}
