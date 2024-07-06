const std = @import("std");
const build_capy = @import("capy");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const capy_dep = b.dependency("capy", .{
        .target = target,
        .optimize = optimize,
        .app_name = @as([]const u8, "capy-template"),
    });
    const capy = capy_dep.module("capy");

    const exe = b.addExecutable(.{
        .name = "capy-template",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("capy", capy);
    b.installArtifact(exe);

    const run_cmd = try build_capy.runStep(exe, .{ .args = b.args });
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(run_cmd);

    // Building for WebAssembly
    @setEvalBranchQuota(5000);
    const wasm = b.addExecutable(.{
        .name = "capy-template",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(
            comptime std.Target.Query.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable,
        ),
        .optimize = optimize,
    });
    wasm.root_module.addImport("capy", capy);
    const serve = try build_capy.runStep(wasm, .{});
    const serve_step = b.step("serve", "Start a local web server to run this application");
    serve_step.dependOn(serve);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
