# Commands
- Make Disk: `dd if=/dev/zero of=test.img bs=1M count=128`
- Build: `zig build`
- QEMU run: `qemu-system-riscv64 -machine virt -bios none -kernel ./zig-out/bin/nosering -nographic -serial mon:stdio -gdb tcp::1234 -drive file=test.img,if=none,format=raw,node-name=test -device virtio-blk-device,drive=test,bus=virtio-mmio-bus.0 -global virtio-mmio.force-legacy=false`
- QEMU debug: `qemu-system-riscv64 -machine virt -bios none -kernel ./zig-out/bin/nosering -nographic -serial mon:stdio -gdb tcp::1234 -drive file=test.img,if=none,format=raw,node-name=test -device virtio-blk-device,drive=test,bus=virtio-mmio-bus.0 -global virtio-mmio.force-legacy=false -S`

