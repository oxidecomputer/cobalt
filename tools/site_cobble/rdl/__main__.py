import sys
import argparse
import os
from pathlib import Path

from systemrdl import RDLCompiler, RDLCompileError, RDLListener, RDLWalker
from systemrdl.node import FieldNode

from exporter import RegBlockExporter
from json_dump import convert_to_json

parser = argparse.ArgumentParser()
parser.add_argument(dest='input_file', help='Input filename')
parser.add_argument('--out-dir', dest='out_dir', default=Path.cwd(), help='Ouput directory')
parser.add_argument('--debug', action="store_true", default=False)


# Define a listener that will print out the register model hierarchy
class MyModelPrintingListener(RDLListener):
    def __init__(self):
        self.indent = 0

    # noinspection PyPep8Naming
    def enter_Component(self, node):
        if not isinstance(node, FieldNode):
            print("\t"*self.indent, node.get_path_segment())
            self.indent += 1

    # noinspection PyPep8Naming
    def enter_Reg(self, node):
        print("\t"*self.indent, "Offset:", node.raw_address_offset)
        print(node.get_property("name"))

    # noinspection PyPep8Naming
    def enter_Field(self, node):
        # Print some stuff about the field
        bit_range_str = "[%d:%d]" % (node.high, node.low)
        sw_access_str = "sw=%s" % node.get_property("sw").name
        print("\t"*self.indent, bit_range_str, node.get_path_segment(), sw_access_str)

    # noinspection PyPep8Naming
    def exit_Component(self, node):
        if not isinstance(node, FieldNode):
            self.indent -= 1


def main():
    rdlc = RDLCompiler()

    try:
        rdlc.compile_file(args.input_file)
        root = rdlc.elaborate()
    except RDLCompileError:
        sys.exit(1)

    if args.debug:
        # Traverse the register model with the printer
        walker = RDLWalker(unroll=True)
        listener = MyModelPrintingListener()
        walker.walk(root, listener)

    # make a path:
    out_path = Path(args.out_dir)
    infile_name = Path(args.input_file).stem

    # Dump Jinja template-based outputs
    exporter = RegBlockExporter()
    exporter.export(root, out_path, infile_name)
    
    # Dump json output
    json_name = out_path / Path(infile_name).with_suffix('.json')
    convert_to_json(rdlc, root, json_name)

args = parser.parse_args()

if __name__ == "__main__":
    main()
