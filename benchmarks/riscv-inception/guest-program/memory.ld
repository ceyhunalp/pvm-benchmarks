SECTIONS {
    . = 0x00000000;
    .text : {
        KEEP(*(.text.entry_point))
        *(.text .text.*)
        *(.rodata) *(.rodata.*)
        *(.data.rel.ro) *(.data.rel.ro.*)
        *(.got) *(.got.*)
        *(.data) *(.data.*)
    }

    .bss : {
        *(.bss)
        *(.bss.*)
        . = ALIGN(16);
        KEEP(*(.stack))
    }

    /DISCARD/ : { *(.eh_frame) }
}
