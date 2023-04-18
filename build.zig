const std = @import("std");
const deps = @import("deps.zig");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimize options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "capy-template",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = try deps.imports.capy.install(exe, .{ .args = b.args });
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(run_cmd);

    // Building for WebAssembly
    // WebAssembly doesn't have a concept of executables, so the way it works is that we make a shared library and capy exports a '_start' function automatically
    @setEvalBranchQuota(5000);
    const wasm = b.addSharedLibrary(.{
        .name = "capy-template",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = comptime std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable,
        .optimize = optimize,
    });
    const serve = try deps.imports.capy.install(wasm, .{});
    const serve_step = b.step("serve", "Start a local web server to run this application");
    serve_step.dependOn(serve);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
