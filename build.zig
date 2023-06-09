const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = std.zig.CrossTarget{
        .cpu_arch = std.Target.Cpu.Arch.riscv64,
        .os_tag = std.Target.Os.Tag.freestanding,
    };

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("nosering", "src/main.zig");
    exe.code_model = .medium;
    exe.addAssemblyFile("src/entry.S");
    exe.addAssemblyFile("src/ktrap.S");
    exe.addAssemblyFile("src/mtrap.S");
    // Let's not do this yet
    // exe.addAssemblyFile("src/trampoline.S");
    exe.setLinkerScriptPath(std.build.FileSource{ .path = "src/linker.ld" });
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
