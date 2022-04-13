from pathlib import Path
from os import PathLike

from typing import TYPE_CHECKING

from jinja2 import Environment, FileSystemLoader
from systemrdl.node import RootNode, Node
from systemrdl import RDLWalker

from models import AddrMapListener, Register, Field, ReservedField

from utils import to_camel_case, to_snake_case

from typing import Any, Dict, Union, Optional, List


class TemplatedOutput:
    known_templates = {
            '.bsv': 'regpkg_bsv.jinja2',
            '.html': 'regmap_html.jinja2',
            '.adoc': 'regmap_adoc.jinja2',
        }
    def __init__(self, out_dir: PathLike, out_name: PathLike):
        self.out_dir = out_dir
        self.out_name = out_name
        self.template_name = self.known_templates.get(self.out_name.suffix, None)
        if self.template_name is None:
            raise Exception(f'No known template for {str(self.out_name)} specified output')

    @property
    def output_file(self):
        return self.out_dir / self.out_name.name


class RegBlockExporter:
    def __init__(self, **kwargs):
        """
        constructor for the ADOC Exporter class
        :param kwargs:
        """

        # Check for any stray kwargs
        if kwargs:
            raise TypeError(f"got an unexpected keyword argument '{list(kwargs.keys())[0]}")

        # Load jinja templates
        self.env = Environment(loader=FileSystemLoader(Path(__file__).parent / 'templates'), lstrip_blocks=True, trim_blocks=True)
        self.env.filters['to_camel_case'] = to_camel_case
        self.env.filters['to_snake_case'] = to_snake_case
        # Sort of a hack for now, load our jinja templates into a list
        self.templates = [
            # self.env.get_template('regmap_adoc.jinja2'), 
            self.env.get_template('regpkg_bsv.jinja2'), 
            self.env.get_template('regmap_html.jinja2'),
            ]
        self.registers = []
        self.outputs = []

    def export(self, node: Node, path: Union[str, PathLike], output_names: List[str], **kwargs: 'Dict[str, Any]') -> None:
        """
        Perform the export.
        :param node: Top-level node to export
        :param path: Path to output file
        :param kwargs:
        :return:
        """
        # Check for any stray kwargs
        if kwargs:
            raise TypeError(f"got an unexpected keyword argument '{list(kwargs.keys())[0]}")

        if isinstance(node, RootNode):
            node = node.top

        if Path(path).is_dir:
            out_directory = Path(path)
        else:
            out_directory = Path(path).parent

         # Collect the requested outputs
        for name in output_names:
            self.outputs.append(TemplatedOutput(out_directory, name))
        
        # Walk the model and build a data structure in self.registers
        RDLWalker().walk(node, AddrMapListener(self))

       
        
        # Loop our templates outputting files as requested.
        for output in self.outputs:
            # Inject some needed context into the Jinja templates
            context = {
                'output_stem': output.out_name.stem,
                'map_name': node.inst_name,
                'Register': Register,
                'Field': Field,
                'ReservedField': ReservedField,
                'isinstance': isinstance,
                'registers': self.registers
            }
            stream = self.env.get_template(output.template_name).stream(context)
            stream.dump(str(output.output_file))

