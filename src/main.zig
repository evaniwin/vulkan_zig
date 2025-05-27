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
test "align" {
    const num: [8:0]u8 = "hellowor";
    const casted: [*c]const u32 = @ptrCast(@alignCast(num));
    _ = casted;
}
pub var viewportsize: [2]c_int = .{ 400, 400 };
pub var running = true;
const graphics = @import("graphics.zig");
const std = @import("std");
