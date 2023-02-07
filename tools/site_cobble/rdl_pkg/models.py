import copy
from typing import List

from systemrdl import RegNode, FieldNode, MemNode

class UnsupportedRegisterSizeError(Exception):
    pass

class DuplicateEnumNameError(Exception):
    pass

known_enum_names = set()


class BaseModel:
    @classmethod
    def from_node(cls, node: RegNode, prefix_stack, repeated_type=False):
        return cls(node=node, prefix_stack=prefix_stack, repeated_type=repeated_type)

    def __init__(self, **kwargs):
        self.prefix = copy.deepcopy(kwargs.pop('prefix_stack'))
        self.repeated_type = kwargs.pop('repeated_type')
        self.enum_names = set()
        self.node = kwargs.pop('node')
        self.width = self.node.size * 8  # node.size is bytes, we want bits here
        self.type_name = self.node.type_name if self.node.orig_type_name is None else self.node.orig_type_name
        # Want offset from owning address map.
        self.offset = self.node.absolute_address
        self.fields = []
        self._max_field_name_chars = 0

    @property
    def prefixed_name(self):
        return '_'.join(self.prefix) + '_' + self.node.get_path_segment()

    @property
    def name(self):
        # We're generating address maps but we can skip the first address map name, but we want the rest of the elaboration
        return '_'.join(self.prefix[1:]) + '_' + self.node.get_path_segment() if len(self.prefix) > 1 else self.node.get_path_segment()

    def get_property(self, *args, **kwargs):
        """
        Helper function to get RDL property from this register node.
        """
        try:
            prop = self.node.get_property(*args, **kwargs)
        except AttributeError:
            prop = ""
        return prop

class Register(BaseModel):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @property
    def packed_fields(self):
        """
            Returns all the defined register fields, skipping any ReservedFields (undefined spaces)
        """
        return [x for x in self.fields if not isinstance(x, ReservedField)]

    @property
    def has_reset_definition(self):
        """
            RDS doesn't force a reset definition on registers but we may want to conditionally generate
            reset logic if a reset value was specified.
        """
        # Get the reset value for all the fields. If we don't see None in any of them we have defined reset behavior
        a = [x.get_property('reset') for x in self.fields if not isinstance(x, ReservedField)]
        return False if None in a else True

    def elaborate(self):
        """
        Register elaboration consists of sorting the defined fields by the
        low index of the field. We then loop through the fields and
        determine the largest contiguous gaps in the definitions and creating
        ReservedFields that fill into these spaces. These are accumulated in
        a gaps variable, and the gaps and fields are concatenated and
        re-sorted by low index again at the end.
        """
        if self.width != 8:
            raise UnsupportedRegisterSizeError(f"We only support 8bit registers at this time. Register {self.name} has a width of {self.width}")
        
        # sort fields descending by field.low bit
        self.fields.sort(key=lambda x: x.low, reverse=True)
        field_max_name = max(len(fld.name) for fld in self.fields)

        # keep a running size of the largest field name to help with formatting
        self._max_field_name_chars = max(self._max_field_name_chars, field_max_name)
        
        # find gaps and fill in with ReservedFields
        gaps = []
        expected = self.width - 1
        for field in self.fields:
            if field.high != expected:
                gaps.append(ReservedField(expected, field.high + 1))
            expected = field.low - 1

  
        if expected >= 0:
            gaps.append(ReservedField(expected, 0))

        # Combine fields and re-sort, leaving us with a completely specified register
        self.fields = sorted(self.fields + gaps, key=lambda x: x.low, reverse=True)


    def format_field_name(self, name):
        """
        To nicely generate aligned outputs, it's handy to know the max length
        of the names of fields on a per-register basis, this function
        provides formatting padded to the max-length for this purpose. This is
        only "known" at the register level but desired in templates at the
        "field" level so the templates can use this function as necessary.
        """
        return f"{name:<{self._max_field_name_chars}}"


class BaseField:
    """ A base class with common implementations for fields"""
    def bitslice_str(self) -> str:
        if self.high == self.low:
            return str(self.low)
        else:
            return f"{self.high}:{self.low}"

    @property
    def width(self):
        return (self.high - self.low) + 1

    @property
    def mask(self):
        return '{:02x}'.format(((1 << self.width) - 1) << self.low)

    def get_property(self, *args, **kwargs):
        try:
            prop = self.node.get_property(*args, **kwargs)
        except AttributeError:
            prop = ""
        return prop

    @property
    def reset_str(self):
        my_rst = self.node.get_property('reset')
        return "{:#0x}".format(my_rst) if my_rst is not None else "None"

    def has_encode(self):
        return False


class Field(BaseField):
    """ A normal, systemRDL-defined field"""
    @classmethod
    def from_node(cls, node: FieldNode):
        return cls(node=node)

    def __init__(self, **kwargs):
        self.node = kwargs.pop('node')
        self.name = self.node.get_path_segment()
        self.high = self.node.high
        self.low = self.node.low
        self.desc = self.node.get_property('desc')
    
    def has_encode(self):
        return self.node.get_property("encode") is not None

    
    def encode_enums(self):
        return list([(x.name, x.value) for x in self.node.get_property("encode") if self.has_encode()])


class ReservedField(BaseField):
    """ A reserved field, inferred by the gaps in systemRDL definitions"""
    def __init__(self, high, low):
        self.name = '-'
        self.node = None
        self.high = high
        self.low = low
        self.desc = 'Reserved'

class Memory(BaseModel):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)