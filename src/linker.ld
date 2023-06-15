OUTPUT_ARCH("riscv")

/* Use _enter as our entry point to our program */
ENTRY(_enter)

MEMORY
{
  /* Source of ORIGIN: https://github.com/qemu/qemu/blob/master/hw/riscv/virt.c#L97
   * Source of LENGTH: QEMU manual has -m default to be 128MiB
   */
  ram (rwxa): ORIGIN = 0x80000000, LENGTH = 128M
}


/* We are only loading from the file using PT_LOAD, we are not using dynamic linking */
PHDRS
{
  ram_fakerom PT_LOAD;
  ram_init PT_LOAD;
  ram PT_LOAD;
}

/* We are putting everything into RAM */
SECTIONS
{
  /* We align each section by 4K, so mappings for sections are page aligned. We
   * only use it for |text|everything else| though */

  .text : ALIGN(4K) {
    *(.text.init);
    *(.text);
    _trampoline = .;
    /* TODO: Let's not do this yet
    *(.trampoline);
    . = ALIGN(4K);
    ASSERT(. - _trampoline == 0x1000, "error: trampoline doesn't fit inside page");
    */
  } >ram :ram_fakerom

  .rodata : ALIGN(4K) {
    PROVIDE( _global_pointer = . );
    *(.rodata);
  } >ram :ram_fakerom

  .data : ALIGN(4K) {
    *(.data);
  } >ram :ram_init

  .bss : ALIGN(4K) {
    *(.bss);
  } >ram :ram

  PROVIDE( _text_start = ADDR(.text) );
  PROVIDE( _text_end = ADDR(.rodata) );
  PROVIDE( _bss_start = ADDR(.bss) );
  PROVIDE( _bss_end = ADDR(.bss) + SIZEOF(.bss) );

  PROVIDE( _stack_start = _bss_end );
  /* Stack size of 4kB */
  PROVIDE( _stack_end = _stack_start + 0x4000 );

  PROVIDE( _kernel_end = _stack_end);

  PROVIDE( _heap_start = _stack_end );
  PROVIDE( _PHYSTOP = ORIGIN(ram) + LENGTH(ram) );
}
