pub var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
pub const allocator = gpa.allocator();
pub fn main() !void {
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const renderthr = std.Thread.spawn(.{}, render, .{}) catch |err| {
        std.log.err("Unable to spawn thread: {s}", .{@errorName(err)});
        return;
    };
    renderthr.join();
}
fn render() void {
    graphics.draw() catch |err| {
        std.log.err("Rendering Failed: {s}", .{@errorName(err)});
        return;
    };
}
pub var viewportsize: [2]c_int = .{ 800, 800 };
pub var running = true;
const graphics = @import("graphics.zig");
const std = @import("std");
