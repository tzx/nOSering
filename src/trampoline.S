.option norvc

.section .trampoline
.align 4
.global ktrap
ktrap:
  # Save every register into trap frame
  csrw sscratch, x31

  # TODO define trapframe??
  li x31, TRAP_ADDR

  # Save all registers
  sd x0, x31
  sd x1, 8(x31)
  sd x2, 16(x31)
  sd x3, 24(x31)
  sd x4, 32(x31)
  sd x5, 40(x31)
  sd x6, 48(x31)
  sd x7, 56(x31)
  sd x8, 64(x31)
  sd x9, 72(x31)
  sd x10, 80(x31)
  sd x11, 88(x31)
  sd x12, 96(x31)
  sd x13, 104(x31)
  sd x14, 112(x31)
  sd x15, 120(x31)
  sd x16, 128(x31)
  sd x17, 136(x31)
  sd x18, 144(x31)
  sd x19, 152(x31)
  sd x20, 160(x31)
  sd x21, 168(x31)
  sd x22, 176(x31)
  sd x23, 184(x31)
  sd x24, 192(x31)
  sd x25, 200(x31)
  sd x26, 208(x31)
  sd x27, 216(x31)
  sd x28, 224(x31)
  sd x29, 232(x31)
  sd x30, 240(x31)
  # Save x31 or t6 as we used that as temp register
  csrr t0, sscratch
  sd t0, 248(x31)

  li t0, TRAP_HANDLE
  tail t0

.global kret
kret:
  # Restore all registers
  li x31, TRAP_ADDR
  ld x0, x31
  ld x1, 8(x31)
  ld x2, 16(x31)
  ld x3, 24(x31)
  ld x4, 32(x31)
  ld x5, 40(x31)
  ld x6, 48(x31)
  ld x7, 56(x31)
  ld x8, 64(x31)
  ld x9, 72(x31)
  ld x10, 80(x31)
  ld x11, 88(x31)
  ld x12, 96(x31)
  ld x13, 104(x31)
  ld x14, 112(x31)
  ld x15, 120(x31)
  ld x16, 128(x31)
  ld x17, 136(x31)
  ld x18, 144(x31)
  ld x19, 152(x31)
  ld x20, 160(x31)
  ld x21, 168(x31)
  ld x22, 176(x31)
  ld x23, 184(x31)
  ld x24, 192(x31)
  ld x25, 200(x31)
  ld x26, 208(x31)
  ld x27, 216(x31)
  ld x28, 224(x31)
  ld x29, 232(x31)
  ld x30, 240(x31)

  ld x31, 248(x31)

  sret
