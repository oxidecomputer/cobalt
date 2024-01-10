import sys
import argparse
import os
from pathlib import Path

from systemrdl import RDLCompiler, RDLCompileError, RDLWalker
from systemrdl.node import FieldNode

from exporter import MapExporter, MapofMapsExporter
from listeners import PreExportListener, MyModelPrintingListener
from json_dump import convert_to_json

parser = argparse.ArgumentParser()
parser.add_argument('--input', '--inputs', nargs="+", dest='input_file', help='Explicity input list')
parser.add_argument('--out-dir', dest='out_dir', default=Path.cwd(), help='Output directory')
parser.add_argument('--debug', action="store_true", default=False)
parser.add_argument('--outputs', nargs="+", help="Explicit output list")


def main():
    rdlc = RDLCompiler()

    try:
        for infile in args.input_file:
            rdlc.compile_file(infile)
        root = rdlc.elaborate()
    except RDLCompileError:
        sys.exit(1)

    if args.debug:
        # Traverse the register model with the printer
        walker = RDLWalker(unroll=True)
        listener = MyModelPrintingListener()
        walker.walk(root, listener)


    # Run the pre_export listener so we have a list of maps we need to generate
    pre_export = PreExportListener()
    RDLWalker().walk(root, pre_export)

    output_filenames = [Path(x) for x in args.outputs]
    output_filenames_no_json = [x for x in output_filenames if '.json' not in str(x)]
    # For a map of maps, we're going to generate:
    # Address offsets bsv using full address and flattening the naming
    # Address offsets json using full address and flattening the naming??
    # an HTML file of everything
    if pre_export.is_map_of_maps:
        # Dump Jinja template-based outputs (filter out .json)
        exporter = MapofMapsExporter()
        exporter.export(pre_export.maps[0], output_filenames_no_json)
    else:
        # For each standard map, we're going to generate:
        # Standard bsv package from this base address
        # Standard json package from this base address
        # an HTML file of this block
        exporter = MapExporter()
        exporter.export(pre_export.maps[0], output_filenames_no_json)

        # Dump json output if requested
        json_files = [x for x in output_filenames if '.json' in str(x)]
        if len(json_files) == 1:
            json_name = Path(json_files[0])
            convert_to_json(rdlc, root, json_name)
        elif len(json_files) > 1:
            raise Exception(f'Specified too many .json outputs: {json_files.join(",")}')

args = parser.parse_args()

if __name__ == "__main__":
    main()
