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
        outputs = [],
        local: Delta = {},
        using: Delta = {}):
    
    def mkusing(ctx):
        # get absolute path for the sources
        env = ctx.env.subset_require(_ver_keys)
        # Determine output directory since we need to output some files here.
        out_dir = package.outpath(env)
        output_paths = [str(Path(out_dir) / Path(output)) for output in outputs]
        symlinks = [package.linkpath(output) for output in outputs]
        p_env = env.derive({
            RDL_ODIR.name:out_dir,
        })
        product = cobble.target.Product(
            env = p_env,
            inputs = ctx.rewrite_sources(sources), # get absolute path for the sources
            outputs = output_paths,
            rule = 'rdl_script')
        
        for output, path, link in zip(outputs, output_paths, symlinks):
            product.expose(path=path, name=str(Path(output).name))
            product.symlink(target=path, source=link)

        our_using = (
            using, # what the BUILD file requested
            # Plus,
            cobble.env.prepare_delta({
                # Make sure the `latest` symlinks get generated when something
                # uses this Product.
                '__implicit__': symlinks
            })

        )
       

        return (our_using, [product])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )


ninja_rules = {
    'rdl_script': {
        'command': ' python3 $rdl_script --input $in --output $out',
        'description': 'making rdl outputs',
    }
}
