const imageviewcreateinfo = struct {
    allocator: std.mem.Allocator,
    logicaldevice: vk.VkDevice,
    images: []vk.VkImage,
};
const imageviews = struct {
    allocator: std.mem.Allocator,
    logicaldevice: vk.VkDevice,
    imageformat: vk.VkFormat,
    images: []vk.VkImage,
    imageviews: []vk.VkImageView,
    fn createimageviews(imageviewcreateparams: imageviewcreateinfo) !*imageviews {
        const self: *imageviews = try imageviewcreateparams.allocator.create(imageviews);
        self.allocator = imageviewcreateparams.allocator;
        self.logicaldevice = imageviewcreateparams.logicaldevice;
        self.images = imageviewcreateparams.images;

        self.imageviews = try self.allocator.alloc(vk.VkImageView, self.images.len);
        for (0..self.imageviews.len) |i| {
            try createimageview(
                self.images[i],
                &self.imageviews[i],
                self.imageformat,
                vk.VK_IMAGE_ASPECT_COLOR_BIT,
                1,
            );
        }
        return self;
    }
    fn destroyimageviews(self: *imageviews) void {
        for (self.imageviews) |imageview| {
            destroyimageview(self.logicaldevice, imageview);
        }
        self.allocator.free(self.imageviews);
        self.allocator.destroy(self);
    }
};
fn createimageview(
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
fn destroyimageview(logicaldevice: *vklogicaldevice.LogicalDevice, imageview: vk.VkImageView) void {
    vk.vkDestroyImageView(logicaldevice.device, imageview, null);
}

pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const std = @import("std");
