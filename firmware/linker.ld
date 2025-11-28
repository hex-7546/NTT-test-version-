/* ============================================================================
 * File: firmware/linker.ld
 * Linker Script for PicoRV32
 * ============================================================================ */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    .init : {
        KEEP(*(.init))
    } > ROM

    .text : {
        *(.text*)
        *(.rodata*)
    } > ROM

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > RAM AT > ROM
    
    _data_load = LOADADDR(.data);

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    /* Stack grows downward from end of RAM */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    
    /* Heap (if needed) */
    _heap_start = _bss_end;
    _heap_end = _stack_top - 1024;  /* Reserve 1KB for stack */
}