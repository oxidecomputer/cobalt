# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import json
import pathlib
import cobble.env
from cobble.plugin import *
from cobble.git_version import *

GEN_GIT_VERSION_BSV = cobble.env.overrideable_string_key('gen_git_version_bsv',
          help = 'Path of version script')

KEYS = frozenset([GEN_GIT_VERSION_BSV])

_ver_keys = frozenset([GEN_GIT_VERSION_BSV.name, GIT_VERSION_CODE.name, GIT_VERSION_REV_SHA1_SHORT.name])


# This is a *super* ugly hack to force ninja to to do the right thing
# We're going to dump out the current sha + stuff into a json file *only* if it needs to be updated, and we'll make this file
# an implicit dependency to make this run when necessary.
# Cobble envs aren't available at this time since we don't have an environment and we can't rely on ninja unless we have a file
# that changes so we're making a file that changes.
config = GitVersionerConfig('git', 'main', '..', 1000, 48, "", "HEAD")
versioner = GitVersioner(config)
out = {
    'sha': versioner.sha1,
    'code': str(versioner.revision)
}
test_in = {
    'sha': "",
    'code': ""
}

try:
    with open('git_sha_hack.json', 'r') as infile:
        test_in = json.load(infile)
except:
    pass

if (test_in['sha'] != out['sha']) or (test_in['code'] != out['code']):
    print("Git sha changed, updating file")
    with open('git_sha_hack.json', 'w') as outfile:
      json.dump(out, outfile)

@target_def
def bsv_fpga_version(package, name, *,
        deps = [],
        sources = ['./git_sha_hack.json'],
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
        'command': ' python3 $gen_git_version_bsv $out > $out',
        'description': 'gen_git_version_bsv.py $out',
    }
}
