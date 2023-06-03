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
  .text : ALIGN(4K) {
    *(.init);
    *(.text);
  } >ram :ram_fakerom

  .rodata : ALIGN(4K) {
    *(.rodata);
  } >ram :ram_fakerom

  .data : ALIGN(4K) {
    *(.data);
  } >ram :ram_init

  .bss : ALIGN(4K) {
    *(.bss);
  } >ram :ram

  /*
  PROVIDE( bss_start = ADDR(.bss) );
  PROVIDE( bss_end = ADDR(.bss) + SIZEOF(.bss) );
  PROVIDE( data_rom = ADDR(.rodata) );
  PROVIDE( data_start = ADDR(.data) );
  PROVIDE( data_end = ADDR(.data) + SIZEOF(.data) );
  */
}
