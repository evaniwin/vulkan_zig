pub const data = extern struct {
    vertex: [3]f32,
    color: [3]f32,
    texcoord: [2]f32,
};
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
