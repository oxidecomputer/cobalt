# Copyright 2020 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import re
import os.path
from itertools import chain

import cobble.env
from cobble.plugin import *


# Define our Bluespec-specific environment keys and their behavior.
BSC = cobble.env.overrideable_string_key('bsc')
BSC_FLAGS = cobble.env.appending_string_seq_key('bsc_flags')
BSC_BDIR = cobble.env.overrideable_string_key('bsc_bdir')
BO_PATHS = cobble.env.frozenset_key('bluespec_object_paths')
VERILOG_FLAGS = cobble.env.appending_string_seq_key('bluespec_verilog_flags')
TOP_MODULE = cobble.env.overrideable_string_key('bluespec_top_module')

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
KEYS = frozenset([BSC, BSC_FLAGS, BSC_BDIR, BO_PATHS, VERILOG_FLAGS, TOP_MODULE,
    BLUESCAN, BLUESCAN_OBJ, BLUESCAN_MAP, SOURCE_HACK])

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

@target_def
def bluespec_simulation(package, name, *,
        env,
        top,
        module,
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    def mkusing(ctx):
        # This target is.. hum.. not as cleas as we'd like in order to accomodate BSC and how it
        # expects its input. The explanation is as follows:
        #
        # Generating a Bluesim simulation artifact is done in three steps. First, the BSC takes a
        # Bluespec package file and a module name in that package, compile the package into an
        # object (named <package>.bo) and then from that package object (and implicitly picked up
        # dependencies) generate a module object (named <module>.ba).
        #
        # The second step takes this module object and module name and generates an equivalent model
        # in C++ (named <model>{.h,.cxx} and model_<model>{.h,.cxx}).
        #
        # In the third step, BSC takes the generated C++ and any additional externally compiled
        # binary objects (if required) and compiles this into a shared object. Finally it generates
        # an executable shell script which ultimately loads this shared object into the Bluesim
        # framework and executes the simulation.
        #
        # This sounds fine for single package targets, but things get more complicated when
        # considering dependencies. These dependencies are compiled into collections of .bo files
        # with their respective .dyndep files and injected into the BSC compilation process by
        # including the directories containing these objects into a path variable. For any
        # simulation targets with dependencies this means that for the provided top level package an
        # object already exists in the dependency set.
        #
        # The challenges are as follows:
        #
        # - The generation of <package>.bo and <module>.ba happen in a (for the build system) single
        #   observable step, to the same output directory (controlled through the -bdir flag)
        # - If <package>.bo already exists in the output directory BSC will quietly overwrite it
        # - We would prefer not to overwrite the .bo in the dependency tree as we can not guarantee
        #   it won't subtly differ from the more generic copy
        # - We also would like to keep the .ba file from ending up in the same output directories as
        #   the dependency .bo files.
        #
        # This target definition therefor assumes and does the following:
        #
        # - The given top package file is not intended to be a standalone source file and is
        #   required to be present in the dependencies of the target.
        # - The resulting top package .bo is only considered in building the .ba file and otherwise
        #   not uses as a library dependency for other targets
        # - A dyndep is generated for the .ba file to appropriately track changes in dependencies
        # - The package .bo and module .ba files are written to a seperate directory which
        #   implicitly becomes part of the BSC object path. This means that depending on the
        #   directory name, either the freshly generated package .bo or the as part of the
        #   dependency tree is used by the compiler. This behavior is really not desirable, but
        #   since both versions are built using the same BSC flags they should be the same/match the
        #   expectations of the compiler. This assumptions seems to hold up for now.
        #
        # With that out of the way, lets get building.

        # Resolve the top package file to a file.
        top_path = ctx.rewrite_sources([top])[0]

        # Make sure top looks like a Bluespec package file.
        ext_re = re.compile(r'.bsv?$')
        assert ext_re.search(top_path), '%s does not appear to be a Bluespec package' % top_path

        # Extract the top package name and make sure it's found in the the dependency map.
        top_package = ext_re.split(os.path.basename(top_path))[0]
        deps_map = dict(tuple(dd.split('=')) for dd in ctx.env[BLUESCAN_MAP.name].split())
        assert top_package in deps_map, \
            'Bluespec package %s not found as part of target dependencies' % top_package

        # Set up the env for the package .bo, module .ba and dyndep files.
        unique_bo_paths = sorted(ctx.env[BO_PATHS.name])

        object_env = ctx.env.subset_require(_compile_keys).derive({
            SOURCE_HACK.name: [top_path], # Make the output a bit more unique. See above.
            TOP_MODULE.name: module,
            BSC_FLAGS.name: ['-p +:' + ':'.join(unique_bo_paths)],
        })

        object_out = module + '.ba'
        object_dir = package.outpath(object_env)
        object_path = package.outpath(object_env, object_out)

        top_object_path = package.outpath(object_env, top_package + '.bo')
        dyndep_path = object_path + '.dyndep'

        object_env = object_env.derive({
            BSC_BDIR.name: object_dir,
        })

        object = cobble.target.Product(
            env = object_env,
            inputs = [top_path],
            outputs = [object_path, top_object_path],
            dyndep = dyndep_path,
            order_only = [dyndep_path],
            rule = 'generate_bluesim_object',
        )

        # Set the module .ba path as the object for Bluescan to use in the dyndep file. This seems
        # to work.
        dyndep_env = ctx.env.subset_require(_bluescan_keys).derive({
            BLUESCAN_OBJ.name: object_path,
        })

        dyndep = cobble.target.Product(
            env = dyndep_env,
            inputs = [top_path],
            outputs = [dyndep_path],
            rule = 'bluespec_dep_scan',
        )

        # Derive a new environment for the Bluesim binary output path. Note: this environment
        # could/should probably be refined.
        binary_env = ctx.env.subset_require(_compile_keys).derive({
            # Make the output a bit more unique. See above.
            SOURCE_HACK.name: [top_path] + unique_bo_paths,
            TOP_MODULE.name: module,
        })

        # Force the creation of the output dir so as to keep BSC from yelling.
        stamp = cobble.target.Product(
            env = ctx.env.subset([]),
            outputs = [package.outpath(binary_env, '.force-dir-creation')],
            rule = 'bluespec_directory_creation_hack',
        )

        # Set up the env for the Bluesim output.
        binary_dir = package.outpath(binary_env)
        binary_path = package.outpath(binary_env, name)
        binary_env = binary_env.derive({
            BSC_FLAGS.name: [
                '-simdir', binary_dir,
            ],
        })

        binary = cobble.target.Product(
            env = binary_env,
            inputs = [object_path],
            outputs = [binary_path],
            rule = 'link_bluesim_binary',
            implicit = object.outputs,
            order_only = stamp.outputs,
            symlink_as = package.linkpath(name),
        )
        binary.expose(path = binary_path, name = name)

        return (local, [dyndep, object, binary, stamp])

    return cobble.target.Target(
        package = package,
        name = name,
        concrete = True,
        down = lambda _up_unused: package.project.named_envs[env].derive(extra),
        using_and_products = mkusing,
        deps = deps,
    )

ninja_rules = {
    'compile_bluespec_obj': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir $in',
        'description': 'BS $in',
    },
    'generate_bluespec_verilog': {
        'command': '$bsc $bsc_flags -verilog $bluespec_verilog_flags $in',
        'description': 'VERILOG $in',
    },
    'generate_bluesim_object': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir -sim -g $bluespec_top_module $in',
        'description': 'BLUESIM $in:$bluespec_top_module',
    },
    'link_bluesim_binary': {
        'command': '$bsc $bsc_flags -sim -e $bluespec_top_module -o $out $in',
        'description': 'BLUESIM $out',
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
