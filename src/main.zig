const std = @import("std");
const zgt = @import("zgt");

// This is required for youe app to build to WebAssembly and other particular architectures
pub usingnamespace zgt.cross_platform;

pub fn main() !void {
    try zgt.backend.init();
    
    var window = try zgt.Window.init();
    try window.set(
        zgt.Label(.{ .text = "Hello, World" })
    );
    
    window.setTitle("Hello");
    window.resize(250, 100);
    window.show();
    
    zgt.runEventLoop();
}
