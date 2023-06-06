# Commands
- Build: `zig build`
- QEMU run: `qemu-system-riscv64 -machine virt -bios none -kernel ./zig-out/bin/nosering -nographic -serial mon:stdio`
- QEMU debug: `qemu-system-riscv64 -machine virt -bios none -kernel ./zig-out/bin/nosering -nographic -serial mon:stdio -gdb tcp::1234 -S`

