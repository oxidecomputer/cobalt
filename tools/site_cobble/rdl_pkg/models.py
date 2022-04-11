from systemrdl import RegNode, FieldNode, RDLListener, AddrmapNode


class AddrMapListener(RDLListener):
    """
    A listener that builds a simple list of registers each with a list
    of fields.  Once a register is finished we do the elaborate() on
    the register to discover holes, and insert a special kind of
    "ReservedField" there. SystemRDL has no concept of missing
    fields, but we need to know that to effectively generate proper
    register maps, documentation and implementations.
    """

    def __init__(self, exporter):
        """
        It is expected that whatever the exporter is here, it has
        an empty list-like attribute called "registers" since we
        append to that.
        """
        self.exporter = exporter
        self.cur_reg = None
    
    def enter_Addrmap(self, node: AddrmapNode) -> None:
        self.exporter.map_name = node.inst_name;

    def enter_Reg(self, node) -> None:
        """
        Each time we enter a register, we generate a new Register
        from the node type and hold onto it here since we'll append
        all our register's fields as we discover them.
        """
        self.cur_reg = Register.from_node(node)

    def enter_Field(self, node) -> None:
        """
        Each field we find, we generate a Field from the node and
        append it to the fields list of our current register.
        """
        self.cur_reg.fields.append(Field.from_node(node))

    def exit_Reg(self, node):
        """
        When we exit a register, we know it's configuration is complete
        so we run the elaborate method which sorts it, and enumerates
        and fills in the reserved holes, and sorts again. This register
        is then appended to the exporter's list of registers to be used
        in generation of design collateral.
        """
        self.cur_reg.elaborate()
        self.exporter.registers.append(self.cur_reg)
        self.cur_reg = None


class Register:
    @classmethod
    def from_node(cls, node: RegNode):
        return cls(node=node)

    def __init__(self, **kwargs):
        self.node = kwargs.pop('node')
        self.width = self.node.size * 8  # node.size is bytes, we want bits here
        self.name = self.node.get_path_segment()
        self.offset = self.node.raw_address_offset
        self.fields = []
        self._max_field_name_chars = 6  # minimum is 6 for "zerosX"

    @property
    def packed_fields(self):
        return [x for x in self.fields if not isinstance(x, ReservedField)]

    def elaborate(self):
        """
        Register elaboration consists of sorting the defined fields by the
        low index of the field. We then loop through the fields and
        determine the largest contiguous gaps in the definitions and creating
        ReservedFields that fill into these spaces. These are accumulated in
        a gaps variable, and the gaps and fields are contactenated and
        re-sorted by low index again at the end.
        """
        # sort fields descending by field.low bit
        self.fields.sort(key=lambda x: x.low, reverse=True)
        field_max_name = max(len(fld.name) for fld in self.fields)
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

        # Combine fields and re-sort
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
    
    def get_property(self, *args, **kwargs):
        try:
            prop = self.node.get_property(*args, **kwargs)
        except AttributeError:
            prop = ""
        return prop


class BaseField:
    """ A base class with common implementations for fields"""
    def bitslice_str(self) -> str:
        if self.high == self.low:
            return str(self.low)
        else:
            return f"{self.high}:{self.low}"

    def get_property(self, *args, **kwargs):
        try:
            prop = self.node.get_property(*args, **kwargs)
        except AttributeError:
            prop = ""
        return prop


class Field(BaseField):
    """ A normal, systemRDL-defined field"""
    @classmethod
    def from_node(cls, node: FieldNode):
        return cls(node=node)

    def __init__(self, **kwargs):
        self.node = kwargs.pop('node')
        self.name = self.node.get_path_segment()
        self.width = (self.node.high - self.node.low) + 1
        self.high = self.node.high
        self.low = self.node.low
        self.desc = self.node.get_property('desc')
    
    @property
    def mask(self):
        return '{:02x}'.format(((1 << self.width) - 1) << self.low)


class ReservedField(BaseField):
    """ A reserved field, inferred by the gaps in systemRDL definitions"""
    def __init__(self, high, low):
        self.name = '-'
        self.node = None
        self.width = (high - low) + 1
        self.high = high
        self.low = low
        self.desc = 'Reserved'

