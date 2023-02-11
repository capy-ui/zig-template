const std = @import("std");
const deps = @import("deps.zig");

const PATH_TO_CAPY = ".zigmod/deps/git/github.com/capy-ui/capy/";

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
    try deps.imports.capy.install(exe, .{});
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Building for WebAssembly
    // WebAssembly doesn't have a concept of executables, so the way it works is that we make a shared library and capy exports a '_start' function automatically
    @setEvalBranchQuota(5000);
    const wasm = b.addSharedLibrary(.{
        .name = "capy-template",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = comptime std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable,
        .optimize = optimize,
    });
    try deps.imports.capy.install(wasm, .{});

    if (@import("builtin").zig_backend != .stage2_llvm) {
        const serve = WebServerStep.create(b, wasm);
        serve.step.dependOn(&wasm.step);
        const serve_step = b.step("serve", "Start a local web server to run this application");
        serve_step.dependOn(&serve.step);
    } else {
        var step = b.addLog("Please use 'zig build serve -fstage1'", .{});
        const serve_step = b.step("serve", "Start a local web server to run this application");
        serve_step.dependOn(&step.step);
    }

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

const http = deps.imports.apple_pie;

/// Step used for running a web server that can be run with 'zig build serve'
const WebServerStep = struct {
    step: std.build.Step,
    exe: *std.build.LibExeObjStep,
    builder: *std.build.Builder,

    pub fn create(builder: *std.build.Builder, exe: *std.build.LibExeObjStep) *WebServerStep {
        const self = builder.allocator.create(WebServerStep) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.custom, "webserver", builder.allocator, WebServerStep.make),
            .exe = exe,
            .builder = builder,
        };
        return self;
    }

    const Context = struct {
        exe: *std.build.LibExeObjStep,
        builder: *std.build.Builder,
    };

    pub fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(WebServerStep, "step", step);
        const allocator = self.builder.allocator;

        var context = Context{ .builder = self.builder, .exe = self.exe };
        const builder = http.router.Builder(*Context);
        std.debug.print("Web server opened at http://localhost:8080/\n", .{});
        try http.listenAndServe(
            allocator,
            try std.net.Address.parseIp("127.0.0.1", 8080),
            &context,
            comptime http.router.Router(*Context, &.{
                builder.get("/", index),
                builder.get("/capy.js", indexJs),
                builder.get("/zig-app.wasm", wasmFile),
            }),
        );
    }

    fn index(context: *Context, response: *http.Response, request: http.Request) !void {
        const allocator = request.arena;
        const buildRoot = context.builder.build_root;
        const file = try std.fs.cwd().openFile(try std.fs.path.join(allocator, &.{ buildRoot, PATH_TO_CAPY ++ "src/backends/wasm/index.html" }), .{});
        defer file.close();
        const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        try response.headers.put("Content-Type", "text/html");
        try response.writer().writeAll(text);
    }

    fn indexJs(context: *Context, response: *http.Response, request: http.Request) !void {
        const allocator = request.arena;
        const buildRoot = context.builder.build_root;
        const file = try std.fs.cwd().openFile(try std.fs.path.join(allocator, &.{ buildRoot, PATH_TO_CAPY ++ "src/backends/wasm/capy.js" }), .{});
        defer file.close();
        const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        try response.headers.put("Content-Type", "application/javascript");
        try response.writer().writeAll(text);
    }

    fn wasmFile(context: *Context, response: *http.Response, request: http.Request) !void {
        const allocator = request.arena;
        const path = context.exe.getOutputSource().getPath(context.builder);
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        try response.headers.put("Content-Type", "application/wasm");
        try response.writer().writeAll(text);
    }
};
