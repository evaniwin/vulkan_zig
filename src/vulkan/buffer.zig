pub fn createbuffer(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    physicaldevice: *vkinstance.PhysicalDevice,
    buffersize: vk.VkDeviceSize,
    bufferusageflags: vk.VkBufferUsageFlags,
    memorypropertiesflags: vk.VkMemoryPropertyFlags,
    buffer: *vk.VkBuffer,
    buffermemory: *vk.VkDeviceMemory,
) !void {
    var buffercreateinfo: vk.VkBufferCreateInfo = .{};
    buffercreateinfo.sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    buffercreateinfo.size = buffersize;
    buffercreateinfo.usage = bufferusageflags;
    buffercreateinfo.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
    buffercreateinfo.flags = 0;
    if (vk.vkCreateBuffer(logicaldevice.device, &buffercreateinfo, null, buffer) != vk.VK_SUCCESS) {
        std.log.err("Unable to create vertex buffer", .{});
        return error.FailedToCreateVertexBuffer;
    }

    var memoryrequirements: vk.VkMemoryRequirements = .{};
    vk.vkGetBufferMemoryRequirements(logicaldevice.device, buffer.*, &memoryrequirements);

    var allocationinfo: vk.VkMemoryAllocateInfo = .{};
    allocationinfo.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocationinfo.allocationSize = memoryrequirements.size;
    allocationinfo.memoryTypeIndex = try findmemorytype(
        physicaldevice,
        memoryrequirements.memoryTypeBits,
        memorypropertiesflags,
    );
    if (vk.vkAllocateMemory(logicaldevice.device, &allocationinfo, null, buffermemory) != vk.VK_SUCCESS) {
        std.log.err("Unable to Allocate Gpu Memory", .{});
        return error.FailedToAllocateGpuMemory;
    }
    _ = vk.vkBindBufferMemory(logicaldevice.device, buffer.*, buffermemory.*, 0);
}

pub fn findmemorytype(physicaldevice: *vkinstance.PhysicalDevice, typefilter: u32, properties: vk.VkMemoryPropertyFlags) !u32 {
    var memoryproperties: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties(physicaldevice.physicaldevice, &memoryproperties);
    for (0..memoryproperties.memoryTypeCount) |i| {
        if ((typefilter & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0 and (memoryproperties.memoryTypes[i].propertyFlags & properties) != 0) {
            return @intCast(i);
        }
        if (i == std.math.maxInt(u5)) break;
    }
    std.log.err("Unable to find suitable memory type", .{});
    return error.FailedToFindSuitableMemory;
}

pub fn copydatatobuffer(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    buffermemory: vk.VkDeviceMemory,
    buffersize: u64,
    datatype: type,
    data: []datatype,
) void {
    var memdata: ?*anyopaque = undefined;
    _ = vk.vkMapMemory(logicaldevice.device, buffermemory, 0, buffersize, 0, &memdata);
    const ptr: [*]datatype = @ptrCast(@alignCast(memdata));
    std.mem.copyForwards(datatype, ptr[0..data.len], data);
    _ = vk.vkUnmapMemory(logicaldevice.device, buffermemory);
}
pub fn copybuffertobuffer(commandpool: *vkcommandbuffer.commandpool, srcbuffer: vk.VkBuffer, dstbuffer: vk.VkBuffer, size: vk.VkDeviceSize) !void {
    const commandbuffer: vk.VkCommandBuffer = try vkcommandbuffer.beginsingletimecommands(commandpool, 0);
    var copyregion: vk.VkBufferCopy = .{};
    copyregion.srcOffset = 0;
    copyregion.dstOffset = 0;
    copyregion.size = size;
    vk.vkCmdCopyBuffer(commandbuffer, srcbuffer, dstbuffer, 1, &copyregion);
    try vkcommandbuffer.endsingletimecommands(commandpool, commandbuffer, 0);
}
const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const vkinstance = @import("instance.zig");
const vkcommandbuffer = @import("commandbuffer.zig");
const std = @import("std");
