# Copyright 2021 Oxide Computer Company

# Note: This code is a lightly modified version of the systemRDL example JSON dumper
# https://systemrdl-compiler.readthedocs.io/en/latest/examples/json_exporter.html
#
# JSON dumper for registers
# Our modified "SCHEMA"
# Fields:
#   type: "field",
#   inst_name: <string>,
#   lsb: <integer>
#   msb: <integer>
#   reset: <integer>
#   sw_access: <string>
#   desc: <string>
#   #TODO: ENUMS!!!
# --------------------------
# Registers:
#   type: "reg",
#   inst_name: <string>
#   addr_offset: <integer>
#   desc = <string>
#   children: <array of fields>
# ----------------------------
# Address map:
#   type: "addrmap",
#   inst_name: <string>,
#   addr_offset: <integer>
#   children: <array of objects (registers or other address maps)>
import json

from os import PathLike
from typing import Union
from systemrdl import RDLCompiler
from systemrdl.node import RootNode, FieldNode, AddrmapNode, RegfileNode, RegNode, MemNode


def convert_to_json(rdlc: RDLCompiler, obj: RootNode, path: Union[str, PathLike]):
    # Convert entire register model to primitive datatypes (a dict/list tree)
    json_obj = convert_addrmap_or_regfile(rdlc, obj.top)

    # Write to a JSON file
    with open(path, "w") as f:
        json.dump(json_obj, f, indent=4)


def convert_field(rdlc: RDLCompiler, obj: FieldNode) -> dict:
    json_obj = dict()
    json_obj['type'] = "field"
    json_obj['inst_name'] = obj.inst_name
    json_obj['lsb'] = obj.lsb
    json_obj['msb'] = obj.msb
    json_obj['reset'] = obj.get_property('reset')
    json_obj['sw_access'] = obj.get_property('sw').name
    read_se = None if (not obj.get_property('onread')) else obj.get_property('onread').name
    json_obj['se_onread'] = read_se
    write_se = None if (not obj.get_property('onwrite')) else obj.get_property('onwrite').name
    json_obj['se_onwrite'] = write_se
    json_obj['desc'] = obj.get_property('desc')
    if obj.get_property('encode') is not None:
        lst = list();
        for name, value in list([(x.name, x.value) for x in obj.get_property("encode")]):
            lst.append({"name": name, "value": value})
        json_obj['encode'] = lst.copy()
    return json_obj


def convert_reg(rdlc: RDLCompiler, obj: RegNode) -> dict:
    if obj.is_array:
        # Use the RDL Compiler message system to print an error
        # fatal() raises RDLCompileError
        rdlc.msg.fatal(
            "JSON export does not support arrays",
            obj.inst.inst_src_ref
        )
    json_obj = dict()
    json_obj['type'] = 'reg'
    json_obj['inst_name'] = obj.inst_name
    json_obj['addr_offset'] = obj.address_offset
    json_obj['regwidth'] = obj.get_property('regwidth')
    json_obj['min_accesswidth'] = obj.get_property('accesswidth')

    # Iterate over all the fields in this reg and convert them
    json_obj['children'] = []
    for field in obj.fields():
        json_field = convert_field(rdlc, field)
        json_obj['children'].append(json_field)

    return json_obj

def convert_mem(obj: MemNode) -> dict:
    json_obj = dict()
    json_obj['type'] = 'mem'
    json_obj['inst_name'] = obj.inst_name
    json_obj['addr_offset'] = obj.address_offset
    json_obj['memwidth'] = obj.get_property('memwidth')
    json_obj['mementries'] = obj.get_property('mementries')

    return json_obj


def convert_addrmap_or_regfile(rdlc: RDLCompiler, obj: Union[AddrmapNode, RegfileNode]) -> dict:
    if obj.is_array:
        rdlc.msg.fatal(
            "JSON export does not support arrays",
            obj.inst.inst_src_ref
        )

    json_obj = dict()
    if isinstance(obj, AddrmapNode):
        json_obj['type'] = 'addrmap'
    elif isinstance(obj, RegfileNode):
        json_obj['type'] = 'regfile'
    else:
        raise RuntimeError

    json_obj['inst_name'] = obj.inst_name
    json_obj['addr_offset'] = obj.address_offset

    json_obj['children'] = []
    for child in obj.children():
        if isinstance(child, (AddrmapNode, RegfileNode)):
            json_child = convert_addrmap_or_regfile(rdlc, child)
        elif isinstance(child, RegNode):
            json_child = convert_reg(rdlc, child)
        elif isinstance(child, MemNode):
            json_child = convert_mem(child)
        else:
            raise RuntimeError("Unknown child type seen during JSON generation.")

        json_obj['children'].append(json_child)

    return json_obj