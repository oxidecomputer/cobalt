from pathlib import Path
from os import PathLike

from typing import TYPE_CHECKING

from jinja2 import Environment, FileSystemLoader
from systemrdl.node import RootNode, Node
from systemrdl import RDLWalker

from models import Register, Field, ReservedField, Memory
from listeners import BaseListener
from utils import to_camel_case, to_snake_case

from typing import Any, Dict, List

class TemplatedOutput:
    known_templates = {
            '.bsv': 'regpkg_bsv.jinja2',
            '.html': 'regmap_html.jinja2',
            '.adoc': 'regmap_adoc.jinja2',
        }
    def __init__(self, out_name: PathLike, template_name=None):
        self.full_output_path = out_name
        self.template_name = self.known_templates.get(self.full_output_path.suffix, None) if template_name is None else template_name
        if self.template_name is None:
            raise Exception(f'No known template for {str(self.full_output_path.suffix)} specified output')

    @property
    def output_file(self):
        return self.out_dir / self.out_name.name

class OutputUtils:
    def __init__(self, outputs:List[TemplatedOutput]):
        self.outputs = outputs

    def get_entity_name(self, ext):
        filtered = [x for x in self.outputs if ext in str(x.full_output_path)]
        assert len(filtered) == 1
        return filtered[0].full_output_path.stem


class BaseExporter:
    def __init__(self, **kwargs):
        # Check for any stray kwargs
        if kwargs:
            raise TypeError(f"got an unexpected keyword argument '{list(kwargs.keys())[0]}")

        # Load jinja templates
        self.env = Environment(loader=FileSystemLoader(Path(__file__).parent / 'templates'), lstrip_blocks=True, trim_blocks=True)
        self.env.filters['to_camel_case'] = to_camel_case
        self.env.filters['to_snake_case'] = to_snake_case
        self.templates = []
        self.outputs = []

    def _write_files(self, context):
        # Loop our templates outputting files as requested.
        for output in self.outputs:
            stream = self.env.get_template(output.template_name).stream(context)
            stream.dump(str(output.full_output_path))


class MapofMapsExporter(BaseExporter):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Sort of a hack for now, load our jinja templates into a list
        self.templates = [
            self.env.get_template('toplvl_bsv.jinja2'), 
            self.env.get_template('regmap_html.jinja2'),
            ]

    def export(self, node: Node, output_names: List[PathLike], **kwargs: 'Dict[str, Any]') -> None:
        # Check for any stray kwargs
        if kwargs:
            raise TypeError(f"got an unexpected keyword argument '{list(kwargs.keys())[0]}")
        
                # Check for any stray kwargs
        if kwargs:
            raise TypeError(f"got an unexpected keyword argument '{list(kwargs.keys())[0]}")

        if isinstance(node, RootNode):
            node = node.top

         # Collect the requested outputs
        for name in output_names:
            if '.bsv' in str(name):
                self.outputs.append(TemplatedOutput(name, 'toplvl_bsv.jinja2'))
            else:
                self.outputs.append(TemplatedOutput(name))

        # Walk the model and build a data structure in self.registers
        addr_map = BaseListener()
        RDLWalker().walk(node, addr_map)

        out_utils = OutputUtils(self.outputs)
         # Inject some needed context into the Jinja templates
        context = {
            'outputs': out_utils,
            'map_name': node.inst_name,
            'Register': Register,
            'Field': Field,
            'ReservedField': ReservedField,
            'Memory': Memory,
            'isinstance': isinstance,
            'registers': addr_map.registers,
            'flatten_names': True,
        }
        self._write_files(context)


class MapExporter(BaseExporter):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.templates = [
            # self.env.get_template('regmap_adoc.jinja2'), 
            self.env.get_template('regpkg_bsv.jinja2'), 
            self.env.get_template('regmap_html.jinja2'),
            ]

    def export(self, node: Node, output_names: List[PathLike], **kwargs: 'Dict[str, Any]') -> None:
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

         # Collect the requested outputs
        for name in output_names:
            self.outputs.append(TemplatedOutput(name))

        # Walk the model and build a data structure in self.registers
        addr_map = BaseListener()
        RDLWalker().walk(node, addr_map)

         # Inject some needed context into the Jinja templates
        out_utils = OutputUtils(self.outputs)
        context = {
            'outputs': out_utils,
            'map_name': node.inst_name,
            'Register': Register,
            'Field': Field,
            'ReservedField': ReservedField,
            'Memory': Memory,
            'isinstance': isinstance,
            'registers': addr_map.registers,
            'flatten_names': False,
        }

        self._write_files(context)

