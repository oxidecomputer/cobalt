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

from datetime import datetime
from enum import Enum
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
    for (source, orig) in zip(sources_i, sources):
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
        # flags they should be identical for the purposes of generating the desired Verilog or
        # Bluesim output.

        object_out = ctx.env.rewrite(top_package + '.bo')

        products = []

        for module in modules:
            module_ext = 'v' if mod_type == 'verilog' else 'ba'
            # Generate the module output key, which looks like path/to/module.ext.
            module_out = ctx.env.rewrite('%s.%s' % (module, module_ext))

            # Generate the module specific environment. The module name is added to BSC_FLAGS
            # making the environment unique.
            object_env = ctx.env.subset_require(_compile_keys).derive({
                SOURCE_HACK.name: [top_path],
                BSC_FLAGS.name: [
                    '-p +:' + ':'.join(sorted(ctx.env[BO_PATHS.name])),
                    '-%s' % mod_type,
                    '-g %s' % module,
                ],
            })

            # Derive the output path and the subsequent product env using this output path for both
            # the package object and module output.
            out_dir = package.outpath(object_env)
            object_path = os.path.join(out_dir, object_out)
            module_path = os.path.join(out_dir, module_out)

            product_env = object_env.derive({
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
            outdir_stamp = cobble.target.Product(
                env = ctx.env.subset([]),
                outputs = [os.path.join(out_dir, '.force-dir-creation')],
                rule = 'bluespec_directory_creation_hack',
            )

            product = cobble.target.Product(
                env = product_env,
                inputs = [top_path],
                outputs = [module_path, object_path],
                rule = 'generate_bluespec_module',
                dyndep = dyndep_path,
                order_only = outdir_stamp.outputs + dyndep.outputs,
            )

            # Expose the module output for use in downstream rules.
            product.expose(name = module, path = module_path)

            # Add a symlink to latest when this rule is called for a Verilog
            # module and an environment is provided. This allows a Verilog
            # output to be a node without outgoing edges in the build graph,
            # useful when generatating Verilog for inspection or for consumption
            # by a tool not driven using Cobble.
            if not env is None and mod_type == 'verilog':
                product.symlink(
                    target = module_path,
                    source = package.linkpath(module_out))

            # Add to the list of products generated for this target.
            products.extend([outdir_stamp, product, dyndep])

        return (using, products)

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

    # Determine if Colorama is available for import and set up some helpers if
    # it is.
    try:
        from colorama import init, ansi, Fore, Back, Style, Cursor

        init()

        def red(s, block=False):
            if block:
                return f"{Back.RED}{Fore.BLACK}{s}{Style.RESET_ALL}"
            else:
                return f"{Fore.RED}{s}{Style.RESET_ALL}"

        def green(s, block=False):
            if block:
                return f"{Back.GREEN}{Fore.BLACK}{s}{Style.RESET_ALL}"
            else:
                return f"{Fore.GREEN}{s}{Style.RESET_ALL}"

        def green_or_red(pred, s): return green(s) if pred else red(s)
        def clear_line(): return ansi.clear_line()
        def cursor_up(y): return Cursor.UP(y) if y != 0 else ''
        def cursor_back(x): return Cursor.BACK(x) if x != 0 else ''

        colorama_present = True
    except ImportError:
        colorama_present = False

    class Test(object):
        """Test holds logic and state for running a test executable,
        determining pass/fail results and reporting status.
        """

        class Result(Enum):
            UNKNOWN = 0
            PASS = 1
            FAIL = 2

        def __init__(self, name, file_path, vcd_dir):
            self.name = name
            self.file_path = file_path
            self.vcd_dir = vcd_dir
            self.vcd_recorded = False
            self.result = self.Result.UNKNOWN
            self.previous_result = self.Result.UNKNOWN
            self.output = []
            self._proc = None
            self._start = None
            self._end = None
            self._cursor_x = 0
            self._cursor_y = 0

        def init_process(self, record_vcd):
            """Set up the subprocess to execute the test."""
            vcd_path = os.path.join(
                self.vcd_dir,
                f"{os.path.basename(self.file_path)}.vcd")

            cmd = [self.file_path]
            if record_vcd: cmd += ['-V', vcd_path]

            self.vcd_recorded = record_vcd
            self.previous_result = self.result
            self.result = self.Result.UNKNOWN
            self._proc = subprocess.Popen(
                ' '.join(cmd),
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                encoding='utf-8')
            self._start = None
            self._end = None

        def should_run(self, vcd_on_fail):
            # Run if there is no test result.
            first_run = (self.result == self.Result.UNKNOWN)
            # Re-run if FAIL and a VCD file should be generated.
            second_run = (vcd_on_fail and \
                self.result == self.Result.FAIL and \
                not self.vcd_recorded)

            return first_run or second_run

        def run(self, interactive=False):
            assert self._proc.returncode is None, \
                f"can not run uninitialized test {name}"

            self._start = datetime.now()
            # Run the process until a timeout is hit, after which the status of
            # the test is displayed. For non-interactive usecases this value is
            # larger so as to not spam a possible log too much.
            while self._proc.returncode is None:
                try:
                    timeout = (1 if interactive else 30)
                    output, _ = self._proc.communicate(timeout=timeout)
                except subprocess.TimeoutExpired:
                    self.print_status(is_tty=interactive)
            self._end = datetime.now()

            self.output = output.splitlines()
            self._determine_pass_fail()

        def _determine_pass_fail(self):
            # Determine the test result from the shell exit code and test
            # output.
            if self._proc.returncode == 0:
                self.result = self.Result.PASS
            else:
                self.result = self.Result.FAIL

            # Bluesim does not change its exit code if an assert fails, so scan
            # the output for failures.
            if not self.result == self.Result.FAIL:
                for line in self.output:
                    if 'assertion failed' in line:
                        self.result = self.Result.FAIL

        @property
        def passed(self):
            return self.result == self.Result.PASS

        @property
        def failed(self):
            return self.result == self.Result.FAIL

        def print_status(self, is_tty=False):
            if is_tty:
                # Move the cursor to the beginning of the previous line and
                # clear the line.
                preamble = \
                    cursor_back(self._cursor_x) + \
                    cursor_up(self._cursor_y) + \
                    clear_line()
            else:
                preamble = ''

            # Determine the string values for the result block and stopwatch
            # given the current state of the test.
            if self.result == self.Result.UNKNOWN:
                result = '  ....  '
                if is_tty and self._start is not None:
                    stopwatch = str(datetime.now() - self._start)[:-3]
                else:
                    stopwatch = '0:00:00.000'
            elif self.result == self.Result.PASS:
                result = green('  PASS  ', block=True) if is_tty else 'PASS'
                stopwatch = str(self._end - self._start)[:-3]
            elif self.result == self.Result.FAIL:
                result = red('  FAIL  ', block=True) if is_tty else 'FAIL'
                stopwatch = str(self._end - self._start)[:-3]

            # Only use the interactive version when running in an ANSI TTY.
            if is_tty:
                status = f"{result} ({stopwatch})\t .. {self.name}"
            else:
                status = f".. {self.name} {result} ({stopwatch})"

            # Keep track of where the cursor is moving so it can be returned to
            # the appropriate position on a next call.
            self._cursor_x = len(status) + 8
            self._cursor_y = 1
            print(preamble + status)


    def cmd(project, args):
        # Determine if stdout is an ANSI TTY and print using richer formatting.
        # Note that this isn't very portable but works well enough for Linux
        # (and probaly MacOS).
        is_tty = not args.no_ansi_tty and \
            (sys.stdin.isatty() and sys.stdout.isatty()) and \
            colorama_present

        # Allow for some more relaxed queries by attempting to autocomplete the
        # query.
        query_str = args.query

        if not args.exact_query:
            if query_str.endswith('Tests'):
                query_str += '.*'
            if not args.query.endswith('#script'):
                query_str += '#script'

        query = re.compile(query_str)

        try:
            build_start = datetime.now()
            results = cobble.cmd.query_products_and_build(
                project,
                query,
                jobs=getattr(args, 'jobs', None),
                loadavg=getattr(args, 'loadavg', None),
                verbose=args.verbose)
            build_end = datetime.now()

            # No outputs were found. There's no point in trying to run anything
            # so bail.
            if len(results) == 0:
                return 1
        except cobble.target.EvaluationError as e:
            cobble.target.print_evaluation_error(e)
            return 1
        except subprocess.CalledProcessError:
            return 1

        # Make sure the VCD output dir exists before starting any tests.
        vcd_dir = os.path.normpath(os.path.join(
            project.build_dir,
            args.vcd_dir))
        if args.vcd_fail or args.vcd_always:
            os.makedirs(vcd_dir, exist_ok=True)

        # The outputs have been built. Lets attempt to group them in one or more
        # tests suites based on their idents.
        grouped_outputs = {}
        for ident, output in results:
            package, target, output_name = _split_ident(ident)

            if 'Tests_' in target:
                suite, module = target.split('_', maxsplit = 1)
            else:
                suite, module = ('', target)

            if not package in grouped_outputs:
                grouped_outputs[package] = {}
            if not suite in grouped_outputs[package]:
                grouped_outputs[package][suite] = {}
            if not module in grouped_outputs[package][suite]:
                grouped_outputs[package][suite][module] = []

            grouped_outputs[package][suite][module].append(\
                (output.name, output.file_path))

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
        def run_test(file_path, name):
            nonlocal is_tty
            nonlocal args
            nonlocal vcd_dir
            nonlocal tests_passed
            nonlocal tests_failed

            test = Test(name, file_path, vcd_dir)

            while test.should_run(args.vcd_fail):
                record_vcd = args.vcd_always or (args.vcd_fail and test.failed)
                test.init_process(record_vcd)
                if is_tty: test.print_status(is_tty=True)
                test.run(interactive=is_tty)

            # Record the test result in the totals.
            if test.result == Test.Result.PASS:
                if test.previous_result == Test.Result.FAIL:
                    # The test failed on the first run but succeeded on the
                    # second, when generating the VCD. This is a clear
                    # indication of a non-deterministic test, so warn that this
                    # happened and report the test as a failure.
                    tests_failed += 1
                    printf(
                        "Test results for %s different after re-run" % test.name,
                        file=sys.stderr)
                    sys.stderr.flush()
                else:
                    tests_passed += 1
            elif test.result == Test.Result.FAIL:
                tests_failed += 1

            # Render the final test result.
            test.print_status(is_tty=is_tty)

            if (args.verbose or test.failed) and len(test.output) > 0:
                for line in test.output:
                    print(' ', line, sep='')

        # Run the tests and record the results, grouping tests by their
        # package:suite string.
        tests_start = datetime.now()

        package_and_suite = lambda t: f"{t[0]}:{t[1]}"
        for suite_name, tests in groupby(tests, key=package_and_suite):
            # Tests is an iterator but we need to know how many there are in a
            # suite. Pull them into a list so they can be counted.
            tests = list(tests)

            for i, (package, suite, test, path) in enumerate(tests):
                if len(tests) == 1 and len(suite) == 0:
                    # Print the whole package:module string if there is only a
                    # single test and the test suite name appears to be zero
                    # length.
                    run_test(path, f"{package}:{test}")
                else:
                    if i == 0:
                        print(f"\t\t\t{suite_name}" if is_tty else suite_name)
                    run_test(path, test)

        tests_end = datetime.now()

        print()
        print(f"Build Time:\t\t{str(build_end - build_start)[:-3]}")
        print(f"Test Time:\t\t{str(tests_end - tests_start)[:-3]}")
        if is_tty:
            print("Total/Passed/Failed:\t{}/{}/{}".format(
                tests_total,
                green_or_red(tests_passed > 0, tests_passed),
                green_or_red(tests_failed == 0, tests_failed)))
        else:
            print('Total/Passed/Failed:\t'
                f"{tests_total}/{tests_passed}/{tests_failed}")

        return (0 if tests_failed == 0 else 2)

    parser = subparsers.add_parser('bluesim_test',
            help = 'build and run Bluesim tests')
    parser.add_argument('-j', '--jobs',
            help = 'run N build jobs in parallel',
            type = int,
            metavar = 'N',
            dest = 'jobs')
    parser.add_argument('-l', '--loadavg',
            help = "don't start new build jobs if loadavg > N",
            type = float,
            metavar = 'N',
            dest = 'loadavg')
    parser.add_argument('-v', '--verbose',
            help = 'verbose output: print output while building and running',
            action = 'store_true',
            dest = 'verbose')
    parser.add_argument('--exact-query',
            help = 'do not use basic heuristics to auto-complete a partial query',
            action = 'store_true',
            default = False,
            dest = 'exact_query')
    parser.add_argument('--vcd-dir',
            help = 'write VCD files to DIR',
            nargs = '?',
            default = 'vcd',
            metavar = 'DIR',
            dest = 'vcd_dir')
    vcd_args = parser.add_mutually_exclusive_group()
    vcd_args.add_argument('--vcd-fail',
            help = 'on test failure, re-run the test and generate a VCD file',
            action = 'store_true',
            default = False,
            dest = 'vcd_fail')
    vcd_args.add_argument('--vcd-always',
            help = 'always generate a VCD file when running a test',
            action = 'store_true',
            default = False,
            dest = 'vcd_always')
    parser.add_argument('--no-ansi-tty',
            help = 'do not use ANSI TTY escape codes',
            action = 'store_true',
            default = False,
            dest = 'no_ansi_tty')
    parser.add_argument('query',
            help = "Query of products to build and test")
    parser.set_defaults(go = cmd)

    return parser


ninja_rules = {
    'compile_bluespec_obj': {
        'command': '$bsc $bsc_flags -bdir $bsc_bdir $in',
        'description': 'BS OBJECT $in',
    },
    'generate_bluespec_module': {
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
