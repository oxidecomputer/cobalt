In SystemRDL, the `addrmap` is considered an HDL boundary, so we generate package files for each `addrmap`
as a unique, stand-alone artifact. These may contain one or more `regfile` instances.  We have additionally 
special-cased generation of an `addrmap` containing only other `addrmap` instances as a special, top-level
generation to aid in system composability.  An `addrmap` which has both subordinate `addrmaps` and registers
is unsupported at this time and may result in unpredictable results.

Normal address maps are defined in the BUILD file like so:
```
rdl('regs_pkg',
    sources = [
        'gimlet_seq_fpga_regs.rdl'  # <- RDL file with one addrmap instance and some number of registers/regfiles
    ],
    outputs = [
        'GimletSeqFpgaRegs.bsv', # <- Requested output of the addrmap BSV package
        'gimlet_sub_regs.html',  # <- Requested output of the html documentation for this addrmap
        'gimlet_sub_regs.json',  # <- Requested output of the .json for software consumption of this addrmap
    ]
)
bluespec_library('GimletSeqFpgaRegs',
    sources = [
        ':regs_pkg#GimletSeqFpgaRegs.bsv', # <- Bluespec rule for generated .bsv>
    ],
    deps = [
        ':regs_pkg',
    ])
```

If you have a higher-level address map that contains the lower level address maps, you do have to list all the subordinate address maps again, *and* the order needs be from bottom to top or the compiler will complain when it finds un-defined symbols.

Assume the `fake_top.rdl` looks like this (an instantiation of 2 copies fo the previously defined gimlet_seq_fpga_regs.rdl):

```
addrmap top_level_map {
    default regwidth = 8;
    // Instantiate 2 gimlet maps to test nesting
    gimlet_seq_fpga gimlet1;
    gimlet_seq_fpga gimlet2;
};
```

Here's what goes into the BUILD file:

```
rdl('regs_top',
    sources = [
        'gimlet_seq_fpga_regs.rdl', # <- Lowest RDL file with one addrmap (again, still used in above rule)
        'fake_top.rdl' # <-Highest level RDL file with only address maps instantiated
    ],
    outputs = [
        'GimletTopRegs.bsv',  # <- Top-level bsv file. Will contain only integer offsets and the flattened registers names for the whole project.
        'gimlet_regs.html', # <- Top-level html file. Will contain a fully enumerated, flattened address map
    ]
)

bluespec_library('GimletTopRegs',
    sources = [
        ':regs_top#GimletTopRegs.bsv',  # <- Generated Bluespec package rule for inclusion elsewhere
    ],
    deps = [
        ':regs_top',
    ])
```

Enums:
======
Note that bsv can't disambiguate enum members with the same name in the same package.
```
reg {
        name = "A1 SM Status";
        desc = "A1 'live' state machine status";
        default sw = r;

        enum a1_sm_status_enum {
            Idle = 8'h00 {desc = "";};
            Enable = 8'h01 {desc = "";};
            WaitPG = 8'h02 {desc = "";};
            Delay = 8'h03 {desc = "";};
            Done = 8'h05 {desc = "";};
        };

        field {
            desc = "TBD";
            encode =  a1_sm_status_enum;
        } A1SM[7:0];
    } A1SMSTATUS;
```

This will generate enums in the bsv package as follows:
```
// Field Enum encoding
typedef enum {
    IDLE = 0, 
    ENABLE = 1, 
    WAITPG = 2, 
    DELAY = 3, 
    DONE = 5
} A1smstatusA1sm deriving (Eq, Bits, FShow);
```
