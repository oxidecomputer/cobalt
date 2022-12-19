from systemrdl import RDLListener, AddrmapNode, RegfileNode, RegNode, FieldNode, MemNode

from models import Register, Field, Memory

# Define a listener that will print out the register model hierarchy
class MyModelPrintingListener(RDLListener):
    def __init__(self):
        self.indent = 0

    # noinspection PyPep8Naming
    def enter_Component(self, node):
        if not isinstance(node, FieldNode):
            print(" "*self.indent, node.get_path_segment())
            self.indent += 4

    # noinspection PyPep8Naming
    def enter_Reg(self, node):
        print(" "*self.indent, "Name:", node.get_property("name"))
        print(" "*self.indent, "Offset:", node.raw_address_offset)
        print(" "*self.indent, "Address:", node.absolute_address)

    # noinspection PyPep8Naming
    def enter_Field(self, node):
        # Print some stuff about the field
        if node.get_property('encode') is not None:
            my_enum = node.get_property('encode')
            print("Encode: {}".format(my_enum.type_name))
            print("Encode: {}".format(my_enum.members))
            for i in my_enum:
                print(f"Encode: {i.name}")
                print(f"Encode: {i.value}")
                print(f"Encode: {i.rdl_name}")
        bit_range_str = "[%d:%d]" % (node.high, node.low)
        sw_access_str = "sw=%s" % node.get_property("sw").name
        print(" "*self.indent, bit_range_str, node.get_path_segment(), sw_access_str)

    # noinspection PyPep8Naming
    def exit_Component(self, node):
        if not isinstance(node, FieldNode):
            self.indent -= 4

    # noinspection PyPep8Naming
    def enter_Mem(self, node):
        print(" "*self.indent, "Offset:", node.raw_address_offset)
        print(" "*self.indent, "Address:", node.absolute_address)
        print(" "*self.indent, "Entries:", node.get_property('mementries'))
        print(" "*self.indent, "Width:", node.get_property('memwidth'))


# Define a listener that will determine top Address map and other
# lower-level address maps
class PreExportListener(RDLListener):
    def __init__(self):
        self.maps = []  # List[Node]

    def enter_Addrmap(self, node: AddrmapNode) -> None:
        # If we're to top map, we only have AddrmapNodes as children
        self.maps.append(node)

    @property
    def is_map_of_maps(self):
        return all(map(lambda x: isinstance(x, AddrmapNode), self.maps[0].children()))


class BaseListener(RDLListener):
    def __init__(self):
        self.prefix_stack = []
        self.known_types = []
        self.cur_reg = None
        self.registers = []

    def enter_Addrmap(self, node: AddrmapNode) -> None:
        # print(f"Enter Addrmap: {node.inst_name}")
        if not self.is_map_of_maps(node):  # skip appending the map of maps prefix
            self.prefix_stack.append(node.inst_name)

    def exit_Addrmap(self, node: AddrmapNode) -> None:
        if not self.is_map_of_maps(node):  # skip popping the map of maps prefix
            self.prefix_stack.pop()

    def enter_Regfile(self, node: RegfileNode) -> None:
        # print(f"Enter Regfile: {node.inst_name}")
        self.prefix_stack.append(node.inst_name)

    def exit_Regfile(self, node: RegfileNode) -> None:
        self.prefix_stack.pop()

    def enter_Regfile(self, node: RegfileNode) -> None:
        self.prefix_stack.append(node.inst_name)

    def exit_Regfile(self, node: RegfileNode) -> None:
        self.prefix_stack.pop()

    def enter_Reg(self, node: RegNode) -> None:
        # print(f"orig type name: {node.orig_type_name}")
        # print(f"new type name: {node.type_name}")
        # print(f"segment: {node.get_path_segment()}")
        # print(f"Enter reg: {node.inst_name}")
        # print(f"stack: {self.prefix_stack}")
        # 2 cases here:
        # node.orig_type_name is None, use node.type_name
        #

        if (node.type_name in self.known_types) or (node.orig_type_name is not None and node.orig_type_name in self.known_types):
            repeated_type = True
        else:
            if node.orig_type_name is not None:
                self.known_types.append(node.orig_type_name)
            else:
                self.known_types.append(node.type_name)
            repeated_type = False
        self.cur_reg = Register.from_node(node, self.prefix_stack, repeated_type)

    def exit_Reg(self, node):
        """
        When we exit a register, we know it's configuration is complete
        so we run the elaborate method which sorts it, and enumerates
        and fills in the reserved holes, and sorts again. This register
        is then appended list of registers to be used
        in generation of design collateral.
        """
        # print(f"Exit reg: {node.inst_name}")
        self.cur_reg.elaborate()
        self.registers.append(self.cur_reg)
        self.cur_reg = None

    def enter_Field(self, node) -> None:
        # print(f"Enter Field: {node.inst_name}")
        """
        Each field we find, we generate a Field from the node and
        append it to the fields list of our current register.
        """
        self.cur_reg.fields.append(Field.from_node(node))

    def enter_Mem(self, node: MemNode) -> None:
        pass

    def exit_Mem(self, node) -> None:
        if (node.type_name in self.known_types) or (node.orig_type_name is not None and node.orig_type_name in self.known_types):
            repeated_type = True
        else:
            if node.orig_type_name is not None:
                self.known_types.append(node.orig_type_name)
            else:
                self.known_types.append(node.type_name)
            repeated_type = False
        self.registers.append(Memory.from_node(node, self.prefix_stack, repeated_type))

    @staticmethod
    def is_map_of_maps(node):
        return all(map(lambda x: isinstance(x, AddrmapNode), node.children()))
