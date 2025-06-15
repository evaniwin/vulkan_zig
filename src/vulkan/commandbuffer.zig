pub const commandpoolcreateinfo = struct {
    allocator: std.mem.Allocator,
    logicaldevice: vklogicaldevice.LogicalDevice,
    queueFamilyIndex: u32,
    commandbuffergroups: u32,
};
pub const commandpool = struct {
    allocator: std.mem.Allocator,
    logicaldevice: vklogicaldevice.LogicalDevice,
    commandpool: vk.VkCommandPool,
    queueFamilyIndex: u32,
    commandbuffers: [][]vk.VkCommandBuffer,
    commandbuffersallocated: []bool,

    pub fn init(commandpoolcreateparams: commandpoolcreateinfo) !*commandpool {
        const self: *commandpool = try commandpoolcreateparams.allocator.create(commandpool);
        self.allocator = commandpoolcreateparams.allocator;
        self.logicaldevice = commandpoolcreateparams.logicaldevice;
        self.queueFamilyIndex = commandpoolcreateparams.queueFamilyIndex;
        self.commandbuffers = try self.allocator.alloc([]vk.VkCommandBuffer, commandpoolcreateparams.commandbuffergroups);
        self.commandbuffersallocated = try self.allocator.alloc([]bool, commandpoolcreateparams.commandbuffergroups);
        for (0..commandpoolcreateparams.commandbuffergroups) |i| {
            self.commandbuffersallocated[i] = false;
        }

        var Commandpoolcreateinfo: vk.VkCommandPoolCreateInfo = .{};
        Commandpoolcreateinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        Commandpoolcreateinfo.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        Commandpoolcreateinfo.queueFamilyIndex = self.queueFamilyIndex;

        if (vk.vkCreateCommandPool(self.logicaldevice.device, &Commandpoolcreateinfo, null, &self.commandpool) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command Pool", .{});
            return error.CommandPoolCreationFailed;
        }

        return self;
    }
    pub fn createcommandbuffer(self: *commandpool, index: u32, count: u32, commandbufferlevel: vk.VkCommandBufferLevel) !void {
        if (index < 0 or index > self.commandbuffers.len) {
            std.log.err("Invalid index selected choose one between 0 and {d}", .{self.commandbuffers.len});
            return error.UnableToCreateNewCommandBufferGroup;
        }
        if (self.commandbuffersallocated[index]) {
            std.log.err("Index already in use by another command buffer group", .{self.commandbuffers.len});
            return error.UnableToCreateNewCommandBufferGroup;
        }
        self.commandbuffers[index] = try self.allocator.alloc(vk.VkCommandBuffer, count);
        self.commandbuffersallocated[index] = true;

        var allocinfo: vk.VkCommandBufferAllocateInfo = .{};
        allocinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocinfo.commandPool = self.commandpool;
        allocinfo.level = commandbufferlevel;
        allocinfo.commandBufferCount = count;
        if (vk.vkAllocateCommandBuffers(self.logicaldevice.device, &allocinfo, self.commandbuffers[index]) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command buffer", .{});
            return error.CommandBufferAllocationFailed;
        }
    }
    pub fn freecommandbuffer(self: *commandpool, index: u32) void {
        if (index < 0 or index > self.commandbuffers.len) {
            std.log.err("Invalid index selected choose one between 0 and {d}", .{self.commandbuffers.len});
            return;
        }
        if (!self.commandbuffersallocated[index]) {
            std.log.err("Index is not used by any group", .{self.commandbuffers.len});
            return;
        }

        vk.vkFreeCommandBuffers(self.logicaldevice.device, self.commandpool, 1, self.commandbuffers[index]);

        self.allocator.free(self.commandbuffers[index]);
        self.commandbuffersallocated[index] = false;
    }
    pub fn free(self: *commandpool) void {
        vk.vkDestroyCommandPool(self.logicaldevice.device, self.commandpool, null);
        for (0..self.commandbuffers.len) |i| {
            if (self.commandbuffersallocated[i]) {
                self.freecommandbuffer(i);
            }
        }
        self.allocator.free(self.commandbuffers);
        self.allocator.free(self.commandbuffersallocated);
        self.allocator.destroy(self);
    }
};
pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const std = @import("std");
