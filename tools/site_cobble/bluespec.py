# Copyright 2020 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


import os.path
from cobble.plugin import *
import cobble.env
from itertools import chain


# Define our Bluespec-specific environment keys and their behavior.
BSC = cobble.env.overrideable_string_key('bsc')
BSC_FLAGS = cobble.env.appending_string_seq_key('bsc_flags')
BSC_BDIR = cobble.env.overrideable_string_key('bsc_bdir')
BO_PATHS = cobble.env.frozenset_key('bluespec_object_paths')
VERILOG_FLAGS = cobble.env.appending_string_seq_key('bluespec_verilog_flags')

# Bluespec searches directories rather than taking lists of objects. If a
# source file is moved from one target to another, for example, you can wind up
# with a stale object file in one directory, and a current one in another, both
# on the build search path. bsc appears to choose the alphabetically earlier
# one when this happens, which is basically never what you want. To avoid this,
# we include the list of source files in the environment used to distinguish
# object files. This will result in some overbuilding if source files are moved
# between targets, but that's pretty rare.
SOURCE_HACK = cobble.env.frozenset_key('bluespec_source_list_hack')

BLUESCAN = cobble.env.overrideable_string_key('bluescan')
BLUESCAN_OBJ = cobble.env.overrideable_string_key('bluescan_obj')
BLUESCAN_MAP = cobble.env.frozenset_key('bluescan_map',
        readout = lambda s: ' '.join(s))

# Cobble looks for this declaration to register keys:
KEYS = frozenset([BSC, BSC_FLAGS, BSC_BDIR, BO_PATHS, VERILOG_FLAGS, BLUESCAN,
    BLUESCAN_OBJ, BLUESCAN_MAP, SOURCE_HACK])

# Construct some frozen sets for environment subsetting.
# Note: we include __implicit__ in the compile environment because compilation
# references .bo files.
_compile_keys = frozenset(['__order_only__', '__implicit__', BSC.name,
    BSC_FLAGS.name, BO_PATHS.name])
_verilog_keys = _compile_keys | frozenset([VERILOG_FLAGS.name])

_bluescan_keys = frozenset([BLUESCAN.name, BLUESCAN_MAP.name])

def _mapping(path):
    """Generates a 'ModName=path/to/ModName.bo' entry from a bo path."""
    return os.path.splitext(os.path.basename(path))[0] + '=' + path

@target_def
def bluespec_library(package, name, *,
        deps = [],
        sources = [],
        local: Delta = {},
        using: Delta = {}):
    def mkusing(ctx):
        # Generate all products.
        objects, dyndeps, dd_map, stamp = _compile_objects(package, sources, ctx)

        # Collect just the output paths for use below.
        obj_files = list(chain(*(prod.outputs for prod in objects)))

        our_using = (
            # Whatever the BUILD file requested
            using,
            # Plus...
            cobble.env.prepare_delta({
                # Expose all paths where .bos can be found.
                BO_PATHS.name: set(os.path.dirname(f) for f in obj_files),
                # Expose our contribution to the dyndeps.
                BLUESCAN_MAP.name: dd_map,
                # Force creation of our build-dir before any of our dependents
                # run.
                '__order_only__': stamp.outputs,
            }),
        )

        return (our_using, objects + dyndeps + [stamp])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )


def _compile_objects(package, sources, ctx):
    """Implementation factor for targets that compile .bs/.bsv to .bo.

    This operation returns a tuple of products '(objects, dyndeps, dd_map,
    stamp)', where

    - 'objects' is a list of object file products.
    - 'dyndeps' is a list of dyndeps file products.
    - 'dd_map' is a list of local "Module=Path" mappings for bluescan.
    - 'stamp' is a product that will deposit a zero-length file into the build
      output directory, to quiet bsc.
    """
    sources_i = ctx.rewrite_sources(sources)

    # Filter out irrelevant environment information. This initially subsetted
    # environment is used to select the output directory.
    env = ctx.env.subset_require(_compile_keys).derive({
        # Insert the list of sources in the directory to make package output
        # dirs more unique. See comment at top.
        SOURCE_HACK.name: sources_i,
    })

    # Construct the .bo search path
    unique_bo_paths = sorted(env[BO_PATHS.name])

    bsc_flags = ['-p +:' + ':'.join(unique_bo_paths)]
    # Extend the environment with the arguments to the compile_bluespec_obj
    # rule and produce our compilation product.
    p_env = env.derive({
        BSC_FLAGS.name: bsc_flags,
        BSC_BDIR.name: package.outpath(env),
    })

    bos = []
    dyndeps = []
    for (source,orig) in zip(sources_i, sources):
        # Construct the path to the new .bo
        output = package.outpath(env, os.path.splitext(os.path.basename(source))[0] + '.bo')
        # Derive the path of the generated dyndep file.
        dyndep_path = output + '.dyndep'
        bos.append(cobble.target.Product(
            env = p_env,
            outputs = [output],
            rule = 'compile_bluespec_obj',
            inputs = [source],
            order_only = [dyndep_path],
            dyndep = dyndep_path,
        ))

    # Generate the local portion of the dyndep map, so that modules in this
    # library can depend on each other if required.
    local_map = set(_mapping(bo.outputs[0]) for bo in bos)
    scan_env_proto = ctx.env.subset_require(_bluescan_keys).derive({
        BLUESCAN_MAP.name: local_map,
    })

    for bo in bos:
        source = bo.inputs[0]
        output = bo.outputs[0]
        # Re-derive the environment narrowed down to the bluescan arguments.
        scan_env = scan_env_proto.derive({
            BLUESCAN_OBJ.name: output,
        })

        dyndeps.append(cobble.target.Product(
            env = scan_env,
            outputs = [bo.dyndep],
            rule = 'bluespec_dep_scan',
            inputs = [source],
        ))

    # bsc won't give us precise dependency information, but is happy to
    # complain endlessly when we suggest a search path that doesn't yet exist
    # (because we were being overly conservative with our dependency
    # information since it wouldn't help us). To silence this nonsense, we
    # force creation of a meaningless file in every build dir, and propagate it
    # as an implicit.
    empty_env = env.subset([])
    stamp = cobble.target.Product(
        env = empty_env,
        outputs = [package.outpath(env, '.force-dir-creation')],
        rule = 'bluespec_directory_creation_hack',
    )

    return (bos, dyndeps, local_map, stamp)

@target_def
def bluespec_verilog(package, name, *,
        top,
        output,
        deps = [],
        using: Delta = {},
        local: Delta = {}):

    def mkusing(ctx):
        # Generate object file products.
        objects, dyndeps, dd_map_unused, stamp_unused = _compile_objects(package, [top], ctx)
        obj = objects[0]
        dyndep = dyndeps[0]

        # Extract just the paths.
        obj_files = obj.outputs

        # Rewrite the Verilog output in the full environment.
        # Note: not using rewrite_sources because target references aren't
        # legal here.
        out = ctx.env.rewrite(output)

        # Now, subset the environment to the keys that actually affect Verilog
        # generation.
        v_env = ctx.env.subset_require(_verilog_keys)
        output_path = package.outpath(v_env, out)

        # Build flags for bsc
        unique_bo_paths = sorted(ctx.env[BO_PATHS.name])
        flags = [
            '-vdir', package.outpath(v_env),
            '-p +:' + ':'.join(unique_bo_paths),
            '-bdir', os.path.dirname(obj_files[0]),
        ]

        # Further subset bsc's environment for the verilog outputs, to control
        # what variables are passed to Ninja.
        p_env = v_env.derive({
            VERILOG_FLAGS.name: flags,
        })

        verilog = cobble.target.Product(
            env = p_env,
            outputs = obj_files + (output_path,),
            rule = 'generate_bluespec_verilog',
            inputs = ctx.rewrite_sources([top]),
            dyndep = dyndep.outputs[0],
            order_only = dyndep.outputs,
        )
        verilog.expose(path = output_path, name = output)

        our_using = (
            using,
            cobble.env.prepare_delta({
                '__implicit__': [output_path],
            }),
        )

        return (our_using, [dyndep, verilog])

    return cobble.target.Target(
        package = package,
        name = name,
        using_and_products = mkusing,
        deps = deps,
        local = local,
    )

ninja_rules = {
    'compile_bluespec_obj': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir $in',
        'description': 'BS $in',
    },
    'generate_bluespec_verilog': {
        'command': '$bsc -verilog $bluespec_verilog_flags $bsc_flags $in',
        'description': 'VERILOG $in',
    },
    'bluespec_dep_scan': {
        'command': '$bluescan --ninja $out --object $bluescan_obj --source $in $bluescan_map',
        'description': 'BLUESCAN $in',
    },
    'bluespec_directory_creation_hack': {
        'command': 'touch $out',
        'description': 'STAMP $out',
    },
}
