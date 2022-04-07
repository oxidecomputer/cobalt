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


# Helper function to fix up the case into a bsv-standards compatible
# filename.
def to_camel_case(template_string, uppercamel=False):
    return inflection.camelize(template_string, uppercase_first_letter=uppercamel)


@target_def
def rdl(package, name, *,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    
    def mkusing(ctx):
        # get absolute path for the sources
        sources_i = ctx.rewrite_sources(sources)
        env = ctx.env.subset_require(_ver_keys)
        # Determine output directory since we need to output some files here
        # TODO: deal with additional outputs.
        out_dir = package.outpath(env)
        p_env = env.derive({
            RDL_ODIR.name:out_dir,
        })
        in_name = Path(sources_i[0]).stem
        bsv_name = f'{to_camel_case(in_name.lower(), uppercamel=True)}.bsv'
        bsv_pkg = package.outpath(env, bsv_name)
        reg_name = in_name +'.html'
        reg_map = package.outpath(env, reg_name)
        json_name = in_name + '.json'
        reg_json = package.outpath(env, json_name)
        product = cobble.target.Product(
            env = p_env,
            inputs = sources_i,
            outputs = ([bsv_pkg], [reg_json, reg_map]),
            rule = 'rdl_script')

        product.expose(path = bsv_pkg, name = bsv_name)

        product.expose(path = reg_map, name = reg_name)
        product.symlink(target = reg_map, source = package.linkpath(reg_name))

        product.expose(path = reg_json, name = json_name)
        product.symlink(target = reg_json, source = package.linkpath(json_name))
       

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
