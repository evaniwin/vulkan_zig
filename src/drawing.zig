pub const data = extern struct {
    vertex: [3]f32,
    color: [3]f32,
    texcoord: [2]f32,
    pub fn getbindingdescription() vk.VkVertexInputBindingDescription {
        var bindingdescription: vk.VkVertexInputBindingDescription = .{};
        bindingdescription.binding = 0;
        bindingdescription.stride = @sizeOf(data);
        bindingdescription.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
        return bindingdescription;
    }
    pub fn getattributedescruptions() [3]vk.VkVertexInputAttributeDescription {
        var attributedescriptions: [3]vk.VkVertexInputAttributeDescription = undefined;
        attributedescriptions[0].binding = 0;
        attributedescriptions[0].location = 0;
        attributedescriptions[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[0].offset = @offsetOf(data, "vertex");

        attributedescriptions[1].binding = 0;
        attributedescriptions[1].location = 1;
        attributedescriptions[1].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[1].offset = @offsetOf(data, "color");

        attributedescriptions[2].binding = 0;
        attributedescriptions[2].location = 2;
        attributedescriptions[2].format = vk.VK_FORMAT_R32G32_SFLOAT;
        attributedescriptions[2].offset = @offsetOf(data, "texcoord");

        return attributedescriptions;
    }
};
pub const points = extern struct {
    position: [2]f32,
    velocity: [2]f32,
    color: [4]f32,
    pub fn getbindingdescription() vk.VkVertexInputBindingDescription {
        var bindingdescription: vk.VkVertexInputBindingDescription = .{};
        bindingdescription.binding = 0;
        bindingdescription.stride = @sizeOf(points);
        bindingdescription.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
        return bindingdescription;
    }
    pub fn getattributedescruptions() [3]vk.VkVertexInputAttributeDescription {
        var attributedescriptions: [3]vk.VkVertexInputAttributeDescription = undefined;
        attributedescriptions[0].binding = 0;
        attributedescriptions[0].location = 0;
        attributedescriptions[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[0].offset = @offsetOf(points, "position");

        attributedescriptions[1].binding = 0;
        attributedescriptions[1].location = 1;
        attributedescriptions[1].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[1].offset = @offsetOf(points, "velocity");

        attributedescriptions[2].binding = 0;
        attributedescriptions[2].location = 2;
        attributedescriptions[2].format = vk.VK_FORMAT_R32G32_SFLOAT;
        attributedescriptions[2].offset = @offsetOf(points, "color");

        return attributedescriptions;
    }
};
// scalar alignment N
// two element scalar (vec2) alignment 2N
// two or three element scalar (vec3 or vec4) alignment 4N ie alignment 16
// nested structure or matrix alignment 16. for example an array of vec2 should be 16 bytes aligned and the last 8 bytes should be padding
//or structs in a structs should be 16 bytes akigned even if it is a 'struct in a struct in a struct' all structs should be 16 aligned both inner and outter irrelevent of depth
pub const uniformbufferobject_view_lookat_projection_matrix = extern struct {
    model: [4][4]f32 align(16),
    view: [4][4]f32 align(16),
    projection: [4][4]f32 align(16),
};
pub const uniformbufferobject_deltatime = extern struct {
    deltatime: f32 = 1,
};
pub const vk = graphics.vk;
const graphics = @import("graphics.zig");
const helper = @import("helpers.zig");
const utilty = @import("utility.zig");
const main = @import("main.zig");
const std = @import("std");
