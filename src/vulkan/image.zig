pub const imageviewcreateinfo = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    imageformat: vk.VkFormat,
    aspectflags: vk.VkImageAspectFlags,
    images: []vk.VkImage,
};
pub const imageviews = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    imageformat: vk.VkFormat,
    aspectflags: vk.VkImageAspectFlags,
    images: []vk.VkImage,
    imageviews: []vk.VkImageView,
    pub fn createimageviews(imageviewcreateparams: imageviewcreateinfo) !*imageviews {
        const self: *imageviews = try imageviewcreateparams.allocator.create(imageviews);
        self.allocator = imageviewcreateparams.allocator;
        self.logicaldevice = imageviewcreateparams.logicaldevice;
        self.imageformat = imageviewcreateparams.imageformat;
        self.images = imageviewcreateparams.images;
        self.aspectflags = imageviewcreateparams.aspectflags;

        self.imageviews = try self.allocator.alloc(vk.VkImageView, self.images.len);
        for (0..self.imageviews.len) |i| {
            try createimageview(
                self.logicaldevice,
                self.images[i],
                &self.imageviews[i],
                self.imageformat,
                self.aspectflags,
                1,
            );
        }
        return self;
    }
    pub fn destroyimageviews(self: *imageviews) void {
        for (self.imageviews) |imageview| {
            destroyimageview(self.logicaldevice, imageview);
        }
        self.allocator.free(self.imageviews);
        self.allocator.destroy(self);
    }
};

pub fn createframebuffer(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    framebuffer: *vk.VkFramebuffer,
    renderpass: vk.VkRenderPass,
    attachments: []vk.VkImageView,
    extent: vk.VkExtent2D,
) !void {
    var framebuffercreateinfo: vk.VkFramebufferCreateInfo = .{};
    framebuffercreateinfo.sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    framebuffercreateinfo.renderPass = renderpass;
    framebuffercreateinfo.attachmentCount = @intCast(attachments.len);
    framebuffercreateinfo.pAttachments = &attachments[0];
    framebuffercreateinfo.width = extent.width;
    framebuffercreateinfo.height = extent.height;
    framebuffercreateinfo.layers = 1;
    if (vk.vkCreateFramebuffer(logicaldevice.device, &framebuffercreateinfo, null, framebuffer) != vk.VK_SUCCESS) {
        std.log.err("Failed To create frame buffer", .{});
        return error.FrameBufferCreationFailed;
    }
}
pub fn destroyframebuffer(logicaldevice: *vklogicaldevice.LogicalDevice, framebuffer: vk.VkFramebuffer) void {
    vk.vkDestroyFramebuffer(logicaldevice.device, framebuffer, null);
}
pub fn createimageview(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    image: vk.VkImage,
    imageview: *vk.VkImageView,
    format: vk.VkFormat,
    aspectflags: vk.VkImageAspectFlags,
    miplevels: u32,
) !void {
    var createinfo: vk.VkImageViewCreateInfo = .{};
    createinfo.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    createinfo.image = image;

    createinfo.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
    createinfo.format = format;

    createinfo.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
    createinfo.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
    createinfo.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
    createinfo.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;

    createinfo.subresourceRange.aspectMask = aspectflags;
    createinfo.subresourceRange.baseMipLevel = 0;
    createinfo.subresourceRange.levelCount = miplevels;
    createinfo.subresourceRange.baseArrayLayer = 0;
    createinfo.subresourceRange.layerCount = 1;

    if (vk.vkCreateImageView(logicaldevice.device, &createinfo, null, imageview) != vk.VK_SUCCESS) {
        std.log.err("Failed to Create image Views", .{});
        return error.FailedToCreateImageView;
    }
}
pub fn destroyimageview(logicaldevice: *vklogicaldevice.LogicalDevice, imageview: vk.VkImageView) void {
    vk.vkDestroyImageView(logicaldevice.device, imageview, null);
}

pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const std = @import("std");
