pub const commandpoolcreateinfo = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    queueFamilyIndex: u32,
    flags: vk.VkCommandPoolCreateFlags,
    commandbuffers: u32,
};
pub const commandpool = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    commandpool: vk.VkCommandPool,
    queueFamilyIndex: u32,
    flags: vk.VkCommandPoolCreateFlags,
    commandbuffers: [][]vk.VkCommandBuffer,
    commandbuffersallocated: []bool,
    fence: vk.VkFence,

    pub fn init(commandpoolcreateparams: commandpoolcreateinfo) !*commandpool {
        const self: *commandpool = try commandpoolcreateparams.allocator.create(commandpool);
        self.allocator = commandpoolcreateparams.allocator;
        self.logicaldevice = commandpoolcreateparams.logicaldevice;
        self.queueFamilyIndex = commandpoolcreateparams.queueFamilyIndex;
        self.flags = commandpoolcreateparams.flags;
        self.commandbuffers = try self.allocator.alloc([]vk.VkCommandBuffer, commandpoolcreateparams.commandbuffers);
        self.commandbuffersallocated = try self.allocator.alloc(bool, commandpoolcreateparams.commandbuffers);
        for (0..commandpoolcreateparams.commandbuffers) |i| {
            self.commandbuffersallocated[i] = false;
        }

        var Commandpoolcreateinfo: vk.VkCommandPoolCreateInfo = .{};
        Commandpoolcreateinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        Commandpoolcreateinfo.flags = self.flags;
        Commandpoolcreateinfo.queueFamilyIndex = self.queueFamilyIndex;

        if (vk.vkCreateCommandPool(self.logicaldevice.device, &Commandpoolcreateinfo, null, &self.commandpool) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command Pool", .{});
            return error.CommandPoolCreationFailed;
        }
        var fencecreateinfo: vk.VkFenceCreateInfo = .{};
        fencecreateinfo.sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fencecreateinfo.flags = vk.VK_FENCE_CREATE_SIGNALED_BIT;
        if (vk.vkCreateFence(self.logicaldevice.device, &fencecreateinfo, null, &self.fence) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create fence (commandpool)", .{});
            return error.UnableToCreateFence;
        }

        return self;
    }
    pub fn createcommandbuffer(self: *commandpool, index: u32, count: u32, commandbufferlevel: vk.VkCommandBufferLevel) !void {
        if (index < 0 or index > self.commandbuffers.len) {
            std.log.err("Invalid index selected choose one between 0 and {d}", .{self.commandbuffers.len});
            return error.UnableToCreateNewCommandBufferGroup;
        }
        if (self.commandbuffersallocated[index]) {
            std.log.err("Index already in use by another command buffer group", .{});
            return error.UnableToCreateNewCommandBufferGroup;
        }
        self.commandbuffers[index] = try self.allocator.alloc(vk.VkCommandBuffer, count);
        self.commandbuffersallocated[index] = true;

        var allocinfo: vk.VkCommandBufferAllocateInfo = .{};
        allocinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocinfo.commandPool = self.commandpool;
        allocinfo.level = commandbufferlevel;
        allocinfo.commandBufferCount = count;
        if (vk.vkAllocateCommandBuffers(self.logicaldevice.device, &allocinfo, &self.commandbuffers[index][0]) != vk.VK_SUCCESS) {
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
            std.log.err("Index is not used by any group", .{});
            return;
        }

        vk.vkFreeCommandBuffers(self.logicaldevice.device, self.commandpool, 1, &self.commandbuffers[index][0]);

        self.allocator.free(self.commandbuffers[index]);
        self.commandbuffersallocated[index] = false;
    }
    pub fn free(self: *commandpool) void {
        for (0..self.commandbuffers.len) |i| {
            if (self.commandbuffersallocated[i]) {
                self.freecommandbuffer(@intCast(i));
            }
        }
        vk.vkDestroyFence(self.logicaldevice.device, self.fence, null);
        vk.vkDestroyCommandPool(self.logicaldevice.device, self.commandpool, null);
        self.allocator.free(self.commandbuffers);
        self.allocator.free(self.commandbuffersallocated);
        self.allocator.destroy(self);
    }
};
pub fn beginsingletimecommands(Commandpool: *commandpool, index: u32) !vk.VkCommandBuffer {
    _ = vk.vkWaitForFences(
        Commandpool.logicaldevice.device,
        1,
        &Commandpool.fence,
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );
    _ = vk.vkResetFences(Commandpool.logicaldevice.device, 1, &Commandpool.fence);

    try Commandpool.createcommandbuffer(index, 1, vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    var begininfo: vk.VkCommandBufferBeginInfo = .{};
    begininfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begininfo.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

    if (vk.vkBeginCommandBuffer(Commandpool.commandbuffers[index][0], &begininfo) != vk.VK_SUCCESS) {
        std.log.err("Unable to Begin Recording Commandbufffer datatransfer", .{});
        return error.FailedToBeginRecordingCommandBuffer;
    }
    return Commandpool.commandbuffers[index][0];
}
pub fn endsingletimecommands(Commandpool: *commandpool, commandbuffer: vk.VkCommandBuffer, index: u32) !void {
    if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
        std.log.err("Unable to End Recording Commandbufffer datatransfer", .{});
        return error.FailedToEndRecordingCommandBuffer;
    }
    var submitinfo: vk.VkSubmitInfo = .{};
    submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitinfo.commandBufferCount = 1;
    submitinfo.pCommandBuffers = &commandbuffer;

    if (vk.vkQueueSubmit(Commandpool.logicaldevice.graphicsqueue.queue, 1, &submitinfo, Commandpool.fence) != vk.VK_SUCCESS) {
        std.log.err("Unable to Submit Queue", .{});
        return error.QueueSubmissionFailed;
    }
    _ = vk.vkWaitForFences(
        Commandpool.logicaldevice.device,
        1,
        &Commandpool.fence,
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );
    Commandpool.freecommandbuffer(index);
}
pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const std = @import("std");
