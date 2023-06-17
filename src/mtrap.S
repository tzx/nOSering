.global machinevec
.align 4
machinevec:
  # Set bit 5 (0x20) to trigger a supervisor timer interrupt
  # Doesn't work too 0x20 doesn't fit in immediate
  # csrsi sip, 0x20
  # mret

  # Use the scratch register and generate a supervisor timer interrupt
  csrrw t0, mscratch, t0

  # Forward all CPU's timecmp
  lui t0, 8196
  add t0, t0, t0

  li t0, 0x20
  csrs mip, t0
  # Setting bit 5 (0x20) triggers a supervisor timer interrupt
  # csrr sip, t0
  # ori t0, t0, 0x20
  # csrw sip, t0

  # Restore t0
  csrrw t0, mscratch, t0
  mret
