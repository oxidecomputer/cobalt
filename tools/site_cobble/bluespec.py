# Copyright 2021 Oxide Computer Company
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import argparse
import curses
import os.path
import re
import subprocess
import sys
from itertools import chain, groupby

import cobble.env
import cobble.cmd
from cobble.plugin import *
from cobble.target import concrete_products, print_evaluation_error


# Define our Bluespec-specific environment keys and their behavior.
BSC = cobble.env.overrideable_string_key('bsc')
BSC_FLAGS = cobble.env.appending_string_seq_key('bsc_flags')
BSC_BDIR = cobble.env.overrideable_string_key('bsc_bdir')
BO_PATHS = cobble.env.frozenset_key('bluespec_object_paths')

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
BLUESCAN_FLAGS = cobble.env.appending_string_seq_key('bluescan_flags')
BLUESCAN_OBJ = cobble.env.overrideable_string_key('bluescan_obj')
BLUESCAN_MAP = cobble.env.frozenset_key('bluescan_map',
        readout = lambda s: ' '.join(s))

# Cobble looks for this declaration to register keys:
KEYS = frozenset([BSC, BSC_FLAGS, BSC_BDIR, BO_PATHS,
    BLUESCAN, BLUESCAN_FLAGS, BLUESCAN_OBJ, BLUESCAN_MAP, SOURCE_HACK])

# Construct some frozen sets for environment subsetting.
# Note: we include __implicit__ in the compile environment because compilation
# references .bo files.
_compile_keys = frozenset(['__order_only__', '__implicit__', BSC.name,
    BSC_FLAGS.name, BO_PATHS.name])
_bluescan_keys = frozenset([BLUESCAN.name, BLUESCAN_FLAGS.name, BLUESCAN_MAP.name])

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

def _bluespec_modules(package, name, mod_type, *,
        top,
        modules,
        deps = [],
        env = None,
        using: Delta = {},
        local: Delta = {}):
    def mkusing(ctx):
        # Resolve the top package or object to a file.
        top_path = ctx.rewrite_sources([top])[0]

        # Make sure top looks like a reasonable input file.
        ext_re = re.compile(r'.bsv?$')
        assert ext_re.search(top_path), '%s does not appear to be a .bs or .bsv file' % top_path

        top_package = ext_re.split(os.path.basename(top_path))[0]

        # Make sure arguments make sense and we do not generate garbage.
        assert len(modules) != 0, 'No modules provided, output will be empty'
        assert mod_type == 'verilog' or mod_type == 'sim', 'Invalid module type %s' % mod_type

        # When generating Verilog output, BSC expects a package file as input. It will compile this
        # package into an object, whether or not it may already be able to find an object for this
        # package. The package file may or may not already be part of the dependency tree and if it
        # is we do not want to overwrite it since that may trigger re-compilation of other targets.
        #
        # To work around this, derive an environment which is sufficiently different and have BSC
        # write out the object on the side, using it only for this target.
        #
        # Note that if the package is already present in the dependency tree, BSC will be able to
        # use either since we can't remove the .bo path for the other object (as there may be other
        # objects on that path). This is not ideal, but since both objects are built using the same
        # flags they should be identical for the purposes of generating the desired Verilog output.

        # Rewrite outputs into the environment.
        object_out = ctx.env.rewrite(top_package + '.bo')
        module_outs = [ctx.env.rewrite(m) for m in modules]

        env = ctx.env.subset_require(_compile_keys).derive({
            # Insert the list of output modules to make package output dirs more unique. This allows
            # for generating Verilog modules from the same package in two different rules if this is
            # desired for some reason.
            #
            # Note that any (* synthesize *) directives in the package will still cause other
            # modules to be generated and written to disk, but they will not be exposed in the build
            # graph unless includes in the modules argument.
            SOURCE_HACK.name: [top_path] + module_outs,
            BSC_FLAGS.name: [
                '-p +:' + ':'.join(sorted(ctx.env[BO_PATHS.name])),
                '-%s' % mod_type,
            ],
        })

        # Derive the output path and the subsequent product env using this output path for both the
        # package object and Verilog modules.
        out_dir = package.outpath(env)
        object_path = os.path.join(out_dir, object_out)
        module_ext = '.v' if mod_type == 'verilog' else '.ba'
        module_paths = [os.path.join(out_dir, out + module_ext) for out in module_outs]

        p_env = env.derive({
            BSC_FLAGS.name: ['-vdir', out_dir] if mod_type == 'verilog' else [],
            BSC_BDIR.name: out_dir,
        })

        # Derive dyndep env and product for the dyndep file.
        dyndep_out = object_out + '.dyndep'
        dyndep_path = os.path.join(out_dir, dyndep_out)
        dyndep_env = ctx.env.subset_require(_bluescan_keys).derive({
            BLUESCAN_OBJ.name: object_path,
        })

        dyndep = cobble.target.Product(
            env = dyndep_env,
            inputs = [top_path],
            outputs = [dyndep_path],
            rule = 'bluespec_dep_scan',
        )

        # Make sure the vdir/bdir exists by adding a stamp.
        vdir_stamp = cobble.target.Product(
            env = ctx.env.subset([]),
            outputs = [os.path.join(out_dir, '.force-dir-creation')],
            rule = 'bluespec_directory_creation_hack',
        )

        product = cobble.target.Product(
            env = p_env,
            inputs = [top_path],
            outputs = module_paths + [object_path],
            rule = 'generate_bluespec_modules',
            dyndep = dyndep_path,
            order_only = vdir_stamp.outputs + dyndep.outputs,
        )

        symlink_modules = not env is None and mod_type == 'verilog'

        for name, path in zip(module_outs, module_paths):
            product.expose(path = path, name = name)
            if symlink_modules:
                product.symlink(target = path, source = package.linkpath(name + module_ext))

        our_using = (
            using,
            cobble.env.prepare_delta({
                '__implicit__': module_paths,
            }),
        )

        return (our_using, [vdir_stamp, product, dyndep])

    if env is None:
        return cobble.target.Target(
            package = package,
            name = name,
            using_and_products = mkusing,
            deps = deps,
            local = local,
        )
    else:
        return cobble.target.Target(
            package = package,
            name = name,
            concrete = True,
            down = lambda _up_unused: \
                package.project.find_environment(env).derive(local),
            using_and_products = mkusing,
            deps = deps,
        )

@target_def
def bluespec_verilog(package, name, *,
        top,
        modules,
        deps = [],
        env = None,
        using: Delta = {},
        local: Delta = {}):
    return _bluespec_modules(package, name, 'verilog',
        env = env,
        top = top,
        modules = modules,
        deps = deps,
        using = using,
        local = local)

@target_def
def bluespec_sim(package, name, *,
        top,
        modules,
        deps = [],
        using: Delta = {},
        local: Delta = {}):
    return _bluespec_modules(package, name, 'sim',
        top = top,
        modules = modules,
        deps = deps,
        using = using,
        local = local)

@target_def
def bluesim_binary(package, name, *,
        env,
        top,
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    def mkusing(ctx):
        # Resolve the module a Bluesim object file.
        top_path = ctx.rewrite_sources([top])[0]

        # Make sure top looks like a Bluespec package file.
        ext_re = re.compile(r'.ba$')
        assert ext_re.search(top_path), \
            '%s does not appear to be a .ba object file' % top_path

        top_module = ext_re.split(os.path.basename(top_path))[0]

        # Derive a new environment for the Bluesim binary output path. Note: this environment
        # could/should probably be refined.
        env = ctx.env.subset_require(_compile_keys).derive({
            # Make the output a bit more unique. See above.
            SOURCE_HACK.name: [top_path],
            BSC_FLAGS.name: ['-sim', '-e', top_module],
        })

        # Force the creation of the output dir so as to keep BSC from yelling.
        stamp = cobble.target.Product(
            env = ctx.env.subset([]),
            outputs = [package.outpath(env, '.force-dir-creation')],
            rule = 'bluespec_directory_creation_hack',
        )

        # Set up the env for the Bluesim output.
        out_dir = package.outpath(env)
        script_path = package.outpath(env, name)
        so_name = name + '.so'
        so_path = package.outpath(env, so_name)
        p_env = env.derive({
            BSC_BDIR.name: os.path.dirname(top_path),
            BSC_FLAGS.name: [
                '-simdir', out_dir,
            ],
        })

        simulation = cobble.target.Product(
            env = p_env,
            inputs = [top_path],
            outputs = ([script_path], [so_path]),
            rule = 'link_bluesim_binary',
            order_only = stamp.outputs,
        )
        simulation.expose(path = so_path, name = 'so')
        simulation.expose(path = script_path, name = 'script')
        simulation.symlink(target = so_path, source = package.linkpath(so_name))
        simulation.symlink(
            target = script_path,
            source = package.linkpath(name),
            order_only = [package.linkpath(so_name)])

        return (local, [simulation, stamp])

    return cobble.target.Target(
        package = package,
        name = name,
        concrete = True,
        down = lambda _up_unused: \
            package.project.find_environment(env).derive(extra),
        using_and_products = mkusing,
        deps = deps,
    )

@global_fn
def bluesim_tests(name, *,
        env,
        suite,
        modules = [],
        deps = [],
        local: Delta = {},
        extra: Delta = {}):
    # Add a simulation target and bluesim_binary targets to the build graph.
    bluespec_sim(name,
        top = suite,
        modules = modules,
        deps = deps,
        local = local)
    for test in modules:
        test_name = '{}_{}'.format(name, test)

        bluesim_binary(test_name,
            env = env,
            top = ':{}#{}'.format(name, test),
            deps = [
                ':' + name,
            ],
            local = local,
            extra = extra)

def _split_ident(s):
    """Split a given ident of the format package:target#output into those
    three parts.
    """
    package, target_and_output = s.split(':')
    target, output = target_and_output.split('#')
    return (package, target, output)

@cmd
def bluesim_test(subparsers):
    """The Bluesim test runner builds targets which look like Bluesim binaries
    and runs them as if unit tests, reporting pass/fail as it goes.
    """

    def cmd(project, args):
        # Allow for some more relaxed queries by appending the output name if it
        # is missing.
        if not args.query.endswith('#script'):
            query = re.compile(args.query + '#script')
        else:
            query = re.compile(args.query)

        try:
            outputs = cobble.cmd.query_products_and_build(
                project,
                query,
                jobs=getattr(args, 'jobs', None),
                loadavg=getattr(args, 'loadavg', None),
                verbose=args.verbose)

            if len(outputs) == 0:
                return 1
        except cobble.target.EvaluationError as e:
            cobble.target.print_evaluation_error(e)
            return 1
        except subprocess.CalledProcessError:
            return 1

        # The outputs have been built. Lets attempt to group them in one or more
        # tests suites based on their idents.
        grouped_outputs = {}
        for ident, path in outputs:
            package, target, output_name = _split_ident(ident)

            if '_' in target:
                suite, module = target.split('_', maxsplit = 1)
            else:
                suite, module = ('', target)

            if not package in grouped_outputs:
                grouped_outputs[package] = {}
            if not suite in grouped_outputs[package]:
                grouped_outputs[package][suite] = {}
            if not module in grouped_outputs[package][suite]:
                grouped_outputs[package][suite][module] = []

            grouped_outputs[package][suite][module].append((output_name, path))

        # Flatten the output structure above into sorted (package, suite,
        # module, path) tuples.
        tests = []
        for package, suites in sorted(grouped_outputs.items()):
            for suite, modules in sorted(suites.items()):
                for module, outputs in sorted(modules.items()):
                    for name, path in outputs:
                        test_name = \
                            module if len(outputs) == 1 else f"{module}#{name}"
                        tests.append((package, suite, test_name, path))

        tests_total = len(tests)
        tests_passed = 0
        tests_failed = 0

        # Run the given test, print some (hopefully) useful info as it goes and
        # report the pass/fail outcome.
        def run_test(test, print_prefix, verbose):
            nonlocal tests_passed
            nonlocal tests_failed

            print(f"{print_prefix}... ", end='')
            sys.stdout.flush()

            proc = subprocess.Popen(
                test,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                encoding='utf-8')
            output, _ = proc.communicate()

            # Determine the test result from the shell exit code and test
            # output.
            failed = (proc.returncode != 0)

            # Bluesim does not change its exit code if an assert fails, so scan
            # the output for failures.
            output = output.splitlines()
            for line in output:
                if line.startswith('Dynamic assertion failed'): failed = True

            if failed:
                tests_failed += 1
            else:
                tests_passed += 1

            # Print the test result.
            print(red_str('FAIL') if failed else green_str('PASS'))
            if failed or verbose:
                for line in output:
                    print('        ' + line)

        # Run the tests and record the results, grouping tests by their
        # package:suite string.
        key = lambda t: f"{t[0]}:{t[1]}"
        for suite_key, tests in groupby(tests, key=key):
            # Tests is an iterator but we need to know how many there are in a
            # suite. Pull them into a list so they can be counted.
            tests = list(tests)

            for i, (package, suite, test, path) in enumerate(tests):
                if len(tests) == 1 and len(suite) == 0:
                    # Print the whole package:module string if there is only a
                    # single test and there does not appear to be a test suite.
                    run_test(path, f"{package}:{test}", args.verbose)
                else:
                    if i == 0:
                        print(suite_key)
                    run_test(path, f"    {test}", args.verbose)

        print()
        print("Total/Passed/Failed: {}/{}/{}".format(
            tests_total,
            green_or_red_str(tests_passed == tests_total, tests_passed),
            green_or_red_str(tests_failed == 0, tests_failed)))

        return (0 if tests_failed == 0 else 2)

    try:
        import colorama

        colorama.init()

        def red_str(s):
            return f"{colorama.Fore.RED}{s}{colorama.Style.RESET_ALL}"
        def green_str(s):
            return f"{colorama.Fore.GREEN}{s}{colorama.Style.RESET_ALL}"
    except ImportError:
        def red_str(s): return s
        def green_str(s): return s

    def green_or_red_str(pred, s):
        return green_str(s) if pred else red_str(s)

    parser = subparsers.add_parser('bluesim_test',
            help = 'build and run Bluesim tests')
    parser.add_argument('-j',
            help = 'run N build jobs in parallel',
            type = int,
            metavar = 'N',
            dest = 'jobs')
    parser.add_argument('-l',
            help = "don't start new build jobs if loadavg > N",
            type = float,
            metavar = 'N',
            dest = 'loadavg')
    parser.add_argument('-v',
            help = "verbose output: print output while building and running",
            action = 'store_true',
            dest = 'verbose')
    parser.add_argument('query',
            help = "Query of products to build and test")
    parser.set_defaults(go = cmd)

    return parser


ninja_rules = {
    'compile_bluespec_obj': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir $in',
        'description': 'BS OBJECT $in',
    },
    'generate_bluespec_modules': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir $in',
        'description': 'BS MODULES $in',
    },
    'link_bluesim_binary': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir -o $out $in',
        'description': 'BLUESIM $in',
    },
    'bluespec_dep_scan': {
        'command': '$bluescan $bluescan_flags --ninja $out --object $bluescan_obj --source $in $bluescan_map',
        'description': 'BLUESCAN $in',
    },
    'bluespec_directory_creation_hack': {
        'command': 'touch $out',
        'description': 'STAMP $out',
    },
}
