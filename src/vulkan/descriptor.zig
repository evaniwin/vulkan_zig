//descriptor layout
pub fn creategraphicsdescriptorsetlayout(logicaldevice: *vklogicaldevice.LogicalDevice, descriptorsetlayout: *vk.VkDescriptorSetLayout) !void {
    var ubolayoutbinding: vk.VkDescriptorSetLayoutBinding = .{};
    ubolayoutbinding.binding = 0;
    ubolayoutbinding.descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    ubolayoutbinding.descriptorCount = 1;
    ubolayoutbinding.stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT;
    ubolayoutbinding.pImmutableSamplers = null;

    var samplerlayoutbinding: vk.VkDescriptorSetLayoutBinding = .{};
    samplerlayoutbinding.binding = 1;
    samplerlayoutbinding.descriptorCount = 1;
    samplerlayoutbinding.descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    samplerlayoutbinding.stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
    samplerlayoutbinding.pImmutableSamplers = null;

    var layoutbindings: [2]vk.VkDescriptorSetLayoutBinding = .{ ubolayoutbinding, samplerlayoutbinding };
    var layoutcreateinfo: vk.VkDescriptorSetLayoutCreateInfo = .{};
    layoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutcreateinfo.bindingCount = @intCast(layoutbindings.len);
    layoutcreateinfo.pBindings = &layoutbindings[0];

    if (vk.vkCreateDescriptorSetLayout(logicaldevice.device, &layoutcreateinfo, null, descriptorsetlayout) != vk.VK_SUCCESS) {
        std.log.err("Unable to create Descriptor Set Layout", .{});
        return error.FailedToCreateDescriptorSetLayout;
    }
}
pub fn createcomputedescriptorsetlayout(logicaldevice: *vklogicaldevice.LogicalDevice, descriptorsetlayout: *vk.VkDescriptorSetLayout) !void {
    var layoutbindings: [3]vk.VkDescriptorSetLayoutBinding = undefined;
    layoutbindings[0].binding = 0;
    layoutbindings[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    layoutbindings[0].descriptorCount = 1;
    layoutbindings[0].stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT;
    layoutbindings[0].pImmutableSamplers = null;

    layoutbindings[1].binding = 1;
    layoutbindings[1].descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    layoutbindings[1].descriptorCount = 1;
    layoutbindings[1].stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT;
    layoutbindings[1].pImmutableSamplers = null;

    layoutbindings[2].binding = 2;
    layoutbindings[2].descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    layoutbindings[2].descriptorCount = 1;
    layoutbindings[2].stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT;
    layoutbindings[2].pImmutableSamplers = null;

    var layoutcreateinfo: vk.VkDescriptorSetLayoutCreateInfo = .{};
    layoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutcreateinfo.bindingCount = @intCast(layoutbindings.len);
    layoutcreateinfo.pBindings = &layoutbindings[0];

    if (vk.vkCreateDescriptorSetLayout(logicaldevice.device, &layoutcreateinfo, null, descriptorsetlayout) != vk.VK_SUCCESS) {
        std.log.err("Unable to create Descriptor Set Layout", .{});
        return error.FailedToCreateDescriptorSetLayout;
    }
}
pub fn destroydescriptorsetlayout(logicaldevice: *vklogicaldevice.LogicalDevice, descriptorsetlayout: vk.VkDescriptorSetLayout) void {
    vk.vkDestroyDescriptorSetLayout(logicaldevice.device, descriptorsetlayout, null);
}

pub const descriptorpoolcreateinfo = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    descriptorsetlayout: vk.VkDescriptorSetLayout,
    descriptorpoolsizes: []vk.VkDescriptorPoolSize,
    descriptorcount: u32,
};
pub const descriptorpool = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    descriptorsetlayout: vk.VkDescriptorSetLayout,
    descriptorpool: vk.VkDescriptorPool,
    descriptorcount: u32,
    descriptorsets: []vk.VkDescriptorSet,
    descriptorsetallocated: bool,
    pub fn init_createdescriptorpool(descriptorpoolcreateparams: descriptorpoolcreateinfo) !*descriptorpool {
        const self: *descriptorpool = try descriptorpoolcreateparams.allocator.create(descriptorpool);
        self.allocator = descriptorpoolcreateparams.allocator;
        self.logicaldevice = descriptorpoolcreateparams.logicaldevice;
        self.descriptorcount = descriptorpoolcreateparams.descriptorcount;
        self.descriptorsetlayout = descriptorpoolcreateparams.descriptorsetlayout;
        self.descriptorsetallocated = false;

        var poolcreateinfo: vk.VkDescriptorPoolCreateInfo = .{};
        poolcreateinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        poolcreateinfo.poolSizeCount = @intCast(descriptorpoolcreateparams.descriptorpoolsizes.len);
        poolcreateinfo.pPoolSizes = &descriptorpoolcreateparams.descriptorpoolsizes[0];
        poolcreateinfo.maxSets = self.descriptorcount;

        if (vk.vkCreateDescriptorPool(self.logicaldevice.device, &poolcreateinfo, null, &self.descriptorpool) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Pool", .{});
            return error.FailedToCreateDescriptorPool;
        }
        return self;
    }
    pub fn destroydescriptorpool(self: *descriptorpool) void {
        vk.vkDestroyDescriptorPool(self.logicaldevice.device, self.descriptorpool, null);
        self.destroydescriptorSets();
        self.allocator.destroy(self);
    }
    pub fn createdescriptorSets_graphics(
        self: *descriptorpool,
        uniformbuffer: []vk.VkBuffer,
        textureimageview: vk.VkImageView,
        textureimagesampler: vk.VkSampler,
    ) !void {
        if (self.descriptorsetallocated) {
            std.log.err("Attempt to allocate an already allocated descriptorset", .{});
            return error.DescriptorsetAlreadyAllocated;
        }
        var descriptorsetlayouts: []vk.VkDescriptorSetLayout = try self.allocator.alloc(vk.VkDescriptorSetLayout, self.descriptorcount);
        defer self.allocator.free(descriptorsetlayouts);
        for (0..self.descriptorcount) |i| {
            descriptorsetlayouts[i] = self.descriptorsetlayout;
        }
        self.descriptorsets = try self.allocator.alloc(vk.VkDescriptorSet, self.descriptorcount);
        self.descriptorsetallocated = true;

        var descriptorsetallocinfo: vk.VkDescriptorSetAllocateInfo = .{};
        descriptorsetallocinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        descriptorsetallocinfo.descriptorPool = self.descriptorpool;
        descriptorsetallocinfo.descriptorSetCount = @intCast(self.descriptorcount);
        descriptorsetallocinfo.pSetLayouts = &descriptorsetlayouts[0];

        if (vk.vkAllocateDescriptorSets(self.logicaldevice.device, &descriptorsetallocinfo, &self.descriptorsets[0]) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Sets", .{});
            return error.FailedToCreateDescriptorSets;
        }
        for (0..self.descriptorcount) |i| {
            var bufferinfo: vk.VkDescriptorBufferInfo = .{};
            bufferinfo.buffer = uniformbuffer[i];
            bufferinfo.offset = 0;
            bufferinfo.range = @sizeOf(drawing.uniformbufferobject_view_lookat_projection_matrix);

            var imageinfo: vk.VkDescriptorImageInfo = .{};
            imageinfo.imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            imageinfo.imageView = textureimageview;
            imageinfo.sampler = textureimagesampler;

            var writedescriptorset: [2]vk.VkWriteDescriptorSet = undefined;
            writedescriptorset[0].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writedescriptorset[0].dstSet = self.descriptorsets[i];
            writedescriptorset[0].dstBinding = 0;
            writedescriptorset[0].dstArrayElement = 0;
            writedescriptorset[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            writedescriptorset[0].descriptorCount = 1;
            writedescriptorset[0].pBufferInfo = &bufferinfo;
            writedescriptorset[0].pImageInfo = null;
            writedescriptorset[0].pTexelBufferView = null;
            writedescriptorset[0].pNext = null;

            writedescriptorset[1].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writedescriptorset[1].dstSet = self.descriptorsets[i];
            writedescriptorset[1].dstBinding = 1;
            writedescriptorset[1].dstArrayElement = 0;
            writedescriptorset[1].descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            writedescriptorset[1].descriptorCount = 1;
            writedescriptorset[1].pBufferInfo = null;
            writedescriptorset[1].pImageInfo = &imageinfo;
            writedescriptorset[1].pTexelBufferView = null;
            writedescriptorset[1].pNext = null;

            vk.vkUpdateDescriptorSets(self.logicaldevice.device, writedescriptorset.len, &writedescriptorset[0], 0, null);
        }
    }
    pub fn createdescriptorSets_compute(
        self: *descriptorpool,
        uniformbuffer: []vk.VkBuffer,
        shaderstoragebuffer: []vk.VkBuffer,
        particlecount: usize,
    ) !void {
        if (self.descriptorsetallocated) {
            std.log.err("Attempt to allocate an already allocated descriptorset", .{});
            return error.DescriptorsetAlreadyAllocated;
        }
        var descriptorsetlayouts: []vk.VkDescriptorSetLayout = try self.allocator.alloc(vk.VkDescriptorSetLayout, self.descriptorcount);
        defer self.allocator.free(descriptorsetlayouts);
        for (0..self.descriptorcount) |i| {
            descriptorsetlayouts[i] = self.descriptorsetlayout;
        }
        self.descriptorsets = try self.allocator.alloc(vk.VkDescriptorSet, self.descriptorcount);
        self.descriptorsetallocated = true;

        var descriptorsetallocinfo: vk.VkDescriptorSetAllocateInfo = .{};
        descriptorsetallocinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        descriptorsetallocinfo.descriptorPool = self.descriptorpool;
        descriptorsetallocinfo.descriptorSetCount = @intCast(self.descriptorcount);
        descriptorsetallocinfo.pSetLayouts = &descriptorsetlayouts[0];

        if (vk.vkAllocateDescriptorSets(self.logicaldevice.device, &descriptorsetallocinfo, &self.descriptorsets[0]) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Sets", .{});
            return error.FailedToCreateDescriptorSets;
        }
        for (0..self.descriptorcount) |i| {
            var uniformbufferinfo: vk.VkDescriptorBufferInfo = .{};
            uniformbufferinfo.buffer = uniformbuffer[i];
            uniformbufferinfo.offset = 0;
            uniformbufferinfo.range = @sizeOf(drawing.uniformbufferobject_deltatime);

            var writedescriptorset: [3]vk.VkWriteDescriptorSet = undefined;
            writedescriptorset[0].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writedescriptorset[0].dstSet = self.descriptorsets[i];
            writedescriptorset[0].dstBinding = 0;
            writedescriptorset[0].dstArrayElement = 0;
            writedescriptorset[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            writedescriptorset[0].descriptorCount = 1;
            writedescriptorset[0].pBufferInfo = &uniformbufferinfo;
            writedescriptorset[0].pImageInfo = null;
            writedescriptorset[0].pTexelBufferView = null;
            writedescriptorset[0].pNext = null;

            var storagebufferlastframeinfo: vk.VkDescriptorBufferInfo = .{};
            storagebufferlastframeinfo.buffer = shaderstoragebuffer[i];
            storagebufferlastframeinfo.offset = 0;
            storagebufferlastframeinfo.range = @sizeOf(drawing.points) * particlecount;

            writedescriptorset[1].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writedescriptorset[1].dstSet = self.descriptorsets[(i + self.descriptorcount - 1) % self.descriptorcount];
            writedescriptorset[1].dstBinding = 1;
            writedescriptorset[1].dstArrayElement = 0;
            writedescriptorset[1].descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            writedescriptorset[1].descriptorCount = 1;
            writedescriptorset[1].pBufferInfo = &storagebufferlastframeinfo;
            writedescriptorset[1].pImageInfo = null;
            writedescriptorset[1].pTexelBufferView = null;
            writedescriptorset[1].pNext = null;

            var storagebuffercurrentframeinfo: vk.VkDescriptorBufferInfo = .{};
            storagebuffercurrentframeinfo.buffer = shaderstoragebuffer[i];
            storagebuffercurrentframeinfo.offset = 0;
            storagebuffercurrentframeinfo.range = @sizeOf(drawing.points) * particlecount;

            writedescriptorset[2].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writedescriptorset[2].dstSet = self.descriptorsets[i];
            writedescriptorset[2].dstBinding = 2;
            writedescriptorset[2].dstArrayElement = 0;
            writedescriptorset[2].descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
            writedescriptorset[2].descriptorCount = 1;
            writedescriptorset[2].pBufferInfo = &storagebuffercurrentframeinfo;
            writedescriptorset[2].pImageInfo = null;
            writedescriptorset[2].pTexelBufferView = null;
            writedescriptorset[2].pNext = null;

            vk.vkUpdateDescriptorSets(self.logicaldevice.device, writedescriptorset.len, &writedescriptorset[0], 0, null);
        }
    }
    fn destroydescriptorSets(self: *descriptorpool) void {
        if (self.descriptorsetallocated) {
            self.allocator.free(self.descriptorsets);
        }
    }
};

pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const drawing = @import("../drawing.zig");
const std = @import("std");
