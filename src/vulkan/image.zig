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
pub fn createimage(
    physicaldevice: *vkinstance.PhysicalDevice,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    width: u32,
    height: u32,
    miplevels: u32,
    numsamples: vk.VkSampleCountFlagBits,
    format: vk.VkFormat,
    tiling: vk.VkImageTiling,
    imageusage: vk.VkImageUsageFlags,
    memproperties: vk.VkMemoryPropertyFlags,
    image: *vk.VkImage,
    imagememory: *vk.VkDeviceMemory,
) !void {
    var imagecreateinfo: vk.VkImageCreateInfo = .{};
    imagecreateinfo.sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imagecreateinfo.imageType = vk.VK_IMAGE_TYPE_2D;
    imagecreateinfo.extent.width = width;
    imagecreateinfo.extent.height = height;
    imagecreateinfo.extent.depth = 1;
    imagecreateinfo.mipLevels = miplevels;
    imagecreateinfo.arrayLayers = 1;
    imagecreateinfo.format = format;
    imagecreateinfo.tiling = tiling;
    imagecreateinfo.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    imagecreateinfo.usage = imageusage;
    imagecreateinfo.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
    imagecreateinfo.samples = numsamples;
    imagecreateinfo.flags = 0;
    if (vk.vkCreateImage(logicaldevice.device, &imagecreateinfo, null, image) != vk.VK_SUCCESS) {
        std.log.err("Unable to create Texture Image", .{});
        return error.FailedToCreateTextureImage;
    }

    var memoryrequirements: vk.VkMemoryRequirements = .{};
    vk.vkGetImageMemoryRequirements(logicaldevice.device, image.*, &memoryrequirements);

    var allocationinfo: vk.VkMemoryAllocateInfo = .{};
    allocationinfo.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocationinfo.allocationSize = memoryrequirements.size;
    allocationinfo.memoryTypeIndex = try vkbuffer.findmemorytype(physicaldevice, memoryrequirements.memoryTypeBits, memproperties);
    if (vk.vkAllocateMemory(logicaldevice.device, &allocationinfo, null, imagememory) != vk.VK_SUCCESS) {
        std.log.err("Unable to create Texture Image Memory", .{});
        return error.FailedToCreateTextureImageMemory;
    }
    _ = vk.vkBindImageMemory(logicaldevice.device, image.*, imagememory.*, 0);
}
pub fn destroyimage(logicaldevice: *vklogicaldevice.LogicalDevice, image: vk.VkImage, imagememory: vk.VkDeviceMemory) void {
    vk.vkDestroyImage(logicaldevice.device, image, null);
    vk.vkFreeMemory(logicaldevice.device, imagememory, null);
}
pub fn transitionimagelayout(commandpool: *vkcommandbuffer.commandpool, image: vk.VkImage, format: vk.VkFormat, oldlayout: vk.VkImageLayout, newlayout: vk.VkImageLayout, miplevels: u32) !void {
    const commandbuffer: vk.VkCommandBuffer = try vkcommandbuffer.beginsingletimecommands(commandpool, 0);
    var barrier: vk.VkImageMemoryBarrier = .{};
    barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.oldLayout = oldlayout;
    barrier.newLayout = newlayout;
    barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
    barrier.image = image;
    barrier.subresourceRange.baseMipLevel = 0;
    barrier.subresourceRange.levelCount = miplevels;
    barrier.subresourceRange.baseArrayLayer = 0;
    barrier.subresourceRange.layerCount = 1;
    if (newlayout == vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL) {
        barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_DEPTH_BIT;

        if (checkstencilcomponent(format)) {
            barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_STENCIL_BIT | vk.VK_IMAGE_ASPECT_DEPTH_BIT;
        } else {
            barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_DEPTH_BIT;
        }
    } else {
        barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
    }
    var sourcestage: vk.VkPipelineStageFlags = undefined;
    var destinationstage: vk.VkPipelineStageFlags = undefined;
    if (oldlayout == vk.VK_IMAGE_LAYOUT_UNDEFINED and newlayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;

        sourcestage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationstage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (oldlayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newlayout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;

        sourcestage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
        destinationstage = vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else if (oldlayout == vk.VK_IMAGE_LAYOUT_UNDEFINED and newlayout == vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

        sourcestage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationstage = vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    } else {
        std.log.err("Unsupported Layout Transition", .{});
        return error.UnsupportedLayoutTransition;
    }
    vk.vkCmdPipelineBarrier(
        commandbuffer,
        sourcestage,
        destinationstage,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );

    try vkcommandbuffer.endsingletimecommands(commandpool, commandbuffer, 0);
}
fn checkstencilcomponent(format: vk.VkFormat) bool {
    return (format == vk.VK_FORMAT_D32_SFLOAT_S8_UINT or format == vk.VK_FORMAT_D24_UNORM_S8_UINT);
}
pub fn copybuffertoimage(commandpool: *vkcommandbuffer.commandpool, buffer: vk.VkBuffer, image: vk.VkImage, width: u32, height: u32) !void {
    const commandbuffer: vk.VkCommandBuffer = try vkcommandbuffer.beginsingletimecommands(commandpool, 0);

    var region: vk.VkBufferImageCopy = .{};
    region.bufferOffset = 0;
    region.bufferRowLength = 0;
    region.bufferImageHeight = 0;

    region.imageSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.mipLevel = 0;
    region.imageSubresource.baseArrayLayer = 0;
    region.imageSubresource.layerCount = 1;

    region.imageOffset = .{ .x = 0, .y = 0, .z = 0 };
    region.imageExtent = .{
        .width = width,
        .height = height,
        .depth = 1,
    };
    vk.vkCmdCopyBufferToImage(
        commandbuffer,
        buffer,
        image,
        vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &region,
    );
    try vkcommandbuffer.endsingletimecommands(commandpool, commandbuffer, 0);
}
pub fn generatemipmaps(physicaldevice: *vkinstance.PhysicalDevice, commandpool: *vkcommandbuffer.commandpool, image: vk.VkImage, imageformat: vk.VkFormat, imgwidth: u32, imgheight: u32, miplevels: u32) !void {
    var formatproperties: vk.VkFormatProperties = .{};
    vk.vkGetPhysicalDeviceFormatProperties(physicaldevice.physicaldevice, imageformat, &formatproperties);
    if ((formatproperties.optimalTilingFeatures & vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) == 0) {
        std.log.err("Minmap generation failed: Device does not suppert linear blitting", .{});
        return error.MinmapGenerationFailed;
    }
    const commandbuffer: vk.VkCommandBuffer = try vkcommandbuffer.beginsingletimecommands(commandpool, 0);
    var mipwidth: i32 = @intCast(imgwidth);
    var mipheight: i32 = @intCast(imgheight);
    var barrier: vk.VkImageMemoryBarrier = .{};
    barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.image = image;
    barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
    barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.baseArrayLayer = 0;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.layerCount = 1;
    for (1..miplevels) |i| {
        barrier.subresourceRange.baseMipLevel = @intCast(i - 1);
        barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT;

        vk.vkCmdPipelineBarrier(
            commandbuffer,
            vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
            vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );

        var blit: vk.VkImageBlit = .{};
        blit.srcOffsets[0] = .{ .x = 0, .y = 0, .z = 0 };
        blit.srcOffsets[1] = .{ .x = mipwidth, .y = mipheight, .z = 1 };
        blit.srcSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        blit.srcSubresource.mipLevel = @intCast(i - 1);
        blit.srcSubresource.baseArrayLayer = 0;
        blit.srcSubresource.layerCount = 1;
        blit.dstOffsets[0] = .{ .x = 0, .y = 0, .z = 0 };

        if (mipwidth > 1) {
            mipwidth = @divTrunc(mipwidth, 2);
        } else {
            mipwidth = 1;
        }
        if (mipheight > 1) {
            mipheight = @divTrunc(mipheight, 2);
        } else {
            mipheight = 1;
        }

        blit.dstOffsets[1] = .{ .x = mipwidth, .y = mipheight, .z = 1 };
        blit.dstSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        blit.dstSubresource.mipLevel = @intCast(i);
        blit.dstSubresource.baseArrayLayer = 0;
        blit.dstSubresource.layerCount = 1;

        vk.vkCmdBlitImage(
            commandbuffer,
            image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &blit,
            vk.VK_FILTER_LINEAR,
        );

        barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        barrier.newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT;
        barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;
        vk.vkCmdPipelineBarrier(
            commandbuffer,
            vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
            vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );
    }
    barrier.subresourceRange.baseMipLevel = miplevels - 1;
    barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT;
    barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;
    vk.vkCmdPipelineBarrier(
        commandbuffer,
        vk.VK_PIPELINE_STAGE_TRANSFER_BIT,
        vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );
    try vkcommandbuffer.endsingletimecommands(commandpool, commandbuffer, 0);
}
pub fn findsupportedformats(physicaldevice: *vkinstance.PhysicalDevice, formatcanadates: []vk.VkFormat, tiling: vk.VkImageTiling, features: vk.VkFormatFeatureFlags) !vk.VkFormat {
    for (formatcanadates) |format| {
        var properties: vk.VkFormatProperties = undefined;
        vk.vkGetPhysicalDeviceFormatProperties(physicaldevice.physicaldevice, format, &properties);
        if (tiling == vk.VK_IMAGE_TILING_LINEAR and ((properties.linearTilingFeatures & features) == features)) {
            return format;
        } else if (tiling == vk.VK_IMAGE_TILING_OPTIMAL and ((properties.optimalTilingFeatures & features) == features)) {
            return format;
        }
    }
    std.log.err("Unable to Find supported format", .{});
    return error.FailedToFindSupportedImageFormat;
}
pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const vkinstance = @import("instance.zig");
const vkcommandbuffer = @import("commandbuffer.zig");
const vkbuffer = @import("buffer.zig");
const std = @import("std");
