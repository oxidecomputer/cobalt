from pathlib import Path
from os import PathLike

from typing import TYPE_CHECKING

from jinja2 import Environment, FileSystemLoader
from systemrdl.node import RootNode, Node
from systemrdl import RDLWalker

from models import AddrMapListener, Register, Field, ReservedField

from utils import to_camel_case, to_snake_case

from typing import Any, Dict, Union, Optional

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

    def export(self, node: Node, path: Union[str, PathLike], name: Optional[str]=None, **kwargs: 'Dict[str, Any]') -> None:
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
        
        # Walk the model and build a data structure in self.registers
        RDLWalker().walk(node, AddrMapListener(self))

        # Inject some needed context into the Jinja templates
        my_name = node.inst_name if name is None else name
        context = {
            'map_name': my_name,
            'Register': Register,
            'Field': Field,
            'ReservedField': ReservedField,
            'isinstance': isinstance,
            'registers': self.registers
        }

        # Loop our templates outputting files as requested.
        for template in self.templates:
            if Path(path).is_dir:
                parent = Path(path)
            else:
                parent = Path(path).parent
            out_path = parent / self._gen_output_name(template.filename, my_name)
            stream = template.stream(context)
            stream.dump(str(out_path))

    @staticmethod
    def _gen_output_name(template_filename, node_name):
        if "bsv" in template_filename:
            return f"{to_camel_case(node_name.lower(), uppercamel=True)}.bsv"
        if "adoc" in template_filename:
            return f"{node_name.lower()}.adoc"
        if "html" in template_filename:
            return f"{node_name.lower()}.html"
