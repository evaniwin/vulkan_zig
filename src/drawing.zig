pub const data = extern struct {
    vertex: [3]f32,
    color: [3]f32,
    texcoord: [2]f32,
};
pub const vertices: [3]data = .{
    .{ .vertex = .{ 0.0, -0.5, 0.0 }, .color = .{ 1.0, 0.0, 0.0 }, .texcoord = .{ 1, 0 } },
    .{ .vertex = .{ 0.5, 0.5, 0.0 }, .color = .{ 0.0, 1.0, 0.0 }, .texcoord = .{ 0, 0 } },
    .{ .vertex = .{ -0.5, 0.5, 0.0 }, .color = .{ 0.0, 0.0, 1.0 }, .texcoord = .{ 0, 1 } },
};
pub const indices: [3]u32 = .{ 0, 1, 2 };
pub const uniformbufferobject = extern struct {
    model: [4][4]f32 align(16),
    view: [4][4]f32 align(16),
    projection: [4][4]f32 align(16),
};

pub const vk = graphics.vk;
const graphics = @import("graphics.zig");
const helper = @import("helpers.zig");
const utilty = @import("utility.zig");
const main = @import("main.zig");
const std = @import("std");
