const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("rock", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    const run_step = b.step("run", "Execute rock");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

// Zig 0.11 version:

// pub fn build(b: *std.build.Builder) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});

//     const exe = b.addExecutable(.{
//         .name = "rock",
//         .root_source_file = .{ .path = "src/main.zig" },
//         .optimize = optimize,
//         .target = target,
//     });

//     b.installArtifact(exe);

//     const test_step = b.step("test", "Run all tests");
//     const test_exe = b.addTest(.{
//         .root_source_file = .{ .path = "src/tokens.zig" },
//         .optimize = optimize,
//         .target = target,
//     });
//     const run_test = b.addRunArtifact(test_exe);

//     test_step.dependOn(&run_test.step);
// }
