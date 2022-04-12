import argparse

from pathlib import Path
from string import Template


parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
)
parser.add_argument(dest='version_code', help="Integer version code")
parser.add_argument(dest='short_sha', help="8 character short SHA")
parser.add_argument(dest='output_filename', help="string for bluespec package name")

template = Template("""
// Auto-generated as part of the FPGA build.
package $package_name;

Bit#(32) version = 'h$version;
Bit#(32) sha = 'h$sha;

function Bit#(8) byte_index(Bit#(32) value, Integer idx);
    return value[8*idx + 7:8*idx];
endfunction

endpackage
""")

if __name__ == '__main__':
    args = parser.parse_args()

    version = f'{int(args.version_code, 0):x}'
    sha = f'{int(args.short_sha, 16):x}'

    package_name = str(Path(args.output_filename).stem)

    print(template.substitute(version=version, sha=sha, package_name=package_name), end='')