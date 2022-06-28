import argparse
import json
from pathlib import Path
from string import Template


parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
)
# parser.add_argument(dest='version_code', help="Integer version code")
# parser.add_argument(dest='short_sha', help="8 character short SHA")
parser.add_argument(dest='output_filename', help="string for bluespec package name")

template = Template("""
// Auto-generated as part of the FPGA build.
package $package_name;

import Vector::*;

Vector#(4, Bit#(8)) version = reverse(unpack('h$version));
Vector#(4, Bit#(8)) sha = reverse(unpack('h$sha));


endpackage
""")

if __name__ == '__main__':
    args = parser.parse_args()

    # version = f'{int(args.version_code, 0):x}'
    # sha = f'{int(args.short_sha, 16):x}'

    with open('git_sha_hack.json', 'r') as infile:
        f = json.load(infile)

    my_code = f['code']
    my_sha = f['sha'][:8]
    version = f'{int(my_code, 0):x}'
    sha = f'{int(my_sha, 16):x}'

    package_name = str(Path(args.output_filename).stem)

    print(template.substitute(version=version, sha=sha, package_name=package_name), end='')