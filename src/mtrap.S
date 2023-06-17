.global machinevec
.align 4
machinevec:
  # Get the scratch space address from the scratch register
  csrrw t0, mscratch, t0

  # Save registers to restore that we will use
  sd t1, 16(t0)
  sd t2, 24(t0)

  # Add the interval
  ld t1, 0(t0)    # CLINT's CMP addr
  ld t2, 0(t1)    # CLINT's CMP
  ld t1, 8(t0)    # Interval to add
  add t2, t1, t2  # t2 = new time = CMP + Interval

  ld t1, 0(t0)    # CLINT's CMP addr
  sd t2, 0(t1)    # CLINT's CMP = new time

  # XXX: Why supervisor timer interrupts suck (for this right now):
  # You can set a supervisor timer interrupt (STIP) in MIP.
  # We can get the interrupt in supervisor mode, but we can't
  # turn the STIP flag off, without going to machine mode or using a SEE
  # STIP is not writable in SIP. We are *not* using an SBI to interface with 
  # SEE. SSIP, however, is writable in supervisor mode.

  li t1, 0x02
  # the SSIP bits in mip and sip seem to correspond, at least in QEMU
  csrs mip, t1

  # Restore registers
  ld t1, 16(t0)
  ld t2, 24(t0)

  # Restore t0
  csrrw t0, mscratch, t0

  mret
