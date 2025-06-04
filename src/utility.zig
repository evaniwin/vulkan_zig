const validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const deviceextensions: [1][*c]const u8 = .{"VK_KHR_swapchain"};
const enablevalidationlayers: bool = true;
const validationlayerverbose: bool = false;
const triangle_frag = @embedFile("spirv/triangle_frag.spv");
const triangle_vert = @embedFile("spirv/triangle_vert.spv");
pub const graphicalcontext = struct {
    allocator: std.mem.Allocator,
    window: *vk.GLFWwindow,
    instance: vk.VkInstance,
    physicaldevice: vk.VkPhysicalDevice,
    physicaldeviceproperties: vk.VkPhysicalDeviceProperties,
    physicaldevicefeatures: vk.VkPhysicalDeviceFeatures,
    device: vk.VkDevice,
    queuelist: *graphicsqueue,
    graphicsqueue: queuestr,
    presentqueue: queuestr,
    debugmessanger: vk.VkDebugUtilsMessengerEXT,
    surface: vk.VkSurfaceKHR,

    swapchain: vk.VkSwapchainKHR,
    swapchainimages: []vk.VkImage,
    swapchainimageformat: vk.VkFormat,
    swapchainextent: vk.VkExtent2D,
    swapchainimageviews: []vk.VkImageView,
    renderpass: vk.VkRenderPass,

    descriptorsetlayout: vk.VkDescriptorSetLayout,
    pipelinelayout: vk.VkPipelineLayout,
    graphicspipeline: vk.VkPipeline,
    swapchainframebuffers: []vk.VkFramebuffer,
    commandpool: vk.VkCommandPool,
    commandpoolonetimecommand: vk.VkCommandPool,
    commandbuffers: []vk.VkCommandBuffer,
    descriptorpool: vk.VkDescriptorPool,
    descriptorsets: []vk.VkDescriptorSet,

    vertexbuffer: vk.VkBuffer,
    vertexbuffermemory: vk.VkDeviceMemory,
    indexbuffer: vk.VkBuffer,
    indexbuffermemory: vk.VkDeviceMemory,
    uniformbuffer: []vk.VkBuffer,
    uniformbuffermemory: []vk.VkDeviceMemory,
    uniformbuffermemotymapped: []?*anyopaque,
    textureimage: vk.VkImage,
    textureimagememory: vk.VkDeviceMemory,
    textureimageview: vk.VkImageView,
    textureimagesampler: vk.VkSampler,
    depthimage: vk.VkImage,
    depthimagememory: vk.VkDeviceMemory,
    depthimageview: vk.VkImageView,

    instanceextensions: *helper.extensionarray,
    imageavailablesephamores: []vk.VkSemaphore,
    renderfinishedsephamores: []vk.VkSemaphore,
    inflightfences: []vk.VkFence,
    temperorycommandbufferinuse: vk.VkFence,
    pub fn init(allocator: std.mem.Allocator, window: *vk.GLFWwindow) !*graphicalcontext {
        //allocate an instance of this struct
        const self: *graphicalcontext = allocator.create(graphicalcontext) catch |err| {
            std.log.err("Unable to allocate memory for vulkan instance: {s}", .{@errorName(err)});
            return err;
        };
        self.allocator = allocator;
        self.window = window;
        //TODO
        errdefer deinit(self);
        //create an vulkan instance
        createinstance(self);
        //setup debug messanger for vulkan validation layer
        try createdebugmessanger(self);
        try createsurface(self);
        try pickphysicaldevice(self);
        self.queuelist = try graphicsqueue.getqueuefamily(self, self.physicaldevice);
        try createlogicaldevice(self);
        try createswapchain(self, null);
        try getswapchainImages(self);
        try createimageviews(self);
        try createsyncobjects(self);
        try createrenderpass(self);
        try createdescriptorsetlayout(self);
        try creategraphicspipeline(self);
        try createcommandpools(self);
        try createdepthresources(self);
        try createframebuffers(self);
        try createtextureimage(self);
        try createtextureimageview(self);
        try createtextureimagesampler(self);
        try createvertexbuffer(self);
        try createindexbuffer(self);
        try createuniformbuffers(self);
        try createdescriptorpool(self);
        try createdescriptorSets(self);
        try createcommandbuffer(self);
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        self.instanceextensions.free();
        destroysyncobjects(self);
        destroytextureimagesampler(self);
        destroytextureimageview(self);
        destroyimage(self, self.textureimage, self.textureimagememory);
        destroycommandpools(self);
        destroyframebuffers(self);
        destroydepthresources(self);
        vk.vkDestroyPipeline(self.device, self.graphicspipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipelinelayout, null);
        vk.vkDestroyRenderPass(self.device, self.renderpass, null);
        destroyimageviews(self);
        destroyswapchainimages(self);
        freeswapchain(self, self.swapchain);
        destroyuniformbuffers(self);
        destroydescriptorpool(self);
        destroydescriptorSets(self);
        destroydescriptorsetlayout(self);
        destroyindexbuffer(self);
        destroyvertexbuffer(self);
        destroylogicaldevice(self);
        destroydebugmessanger(self);
        vk.vkDestroySurfaceKHR(self.instance, self.surface, null);
        vk.vkDestroyInstance(self.instance, null);
        self.allocator.free(self.commandbuffers);
        self.queuelist.deinit();
        self.allocator.destroy(self);
    }
    pub fn recordcommandbuffer(self: *graphicalcontext, commandbuffer: vk.VkCommandBuffer, imageindex: u32) !void {
        var commandbufferbegininfo: vk.VkCommandBufferBeginInfo = .{};
        commandbufferbegininfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        commandbufferbegininfo.flags = 0;
        commandbufferbegininfo.pInheritanceInfo = null;
        if (vk.vkBeginCommandBuffer(commandbuffer, &commandbufferbegininfo) != vk.VK_SUCCESS) {
            std.log.err("Unable to Begin Recording Commandbufffer", .{});
            return error.FailedToBeginRecordingCommandBuffer;
        }

        var renderpassbegininfo: vk.VkRenderPassBeginInfo = .{};
        renderpassbegininfo.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderpassbegininfo.renderPass = self.renderpass;
        renderpassbegininfo.framebuffer = self.swapchainframebuffers[imageindex];
        renderpassbegininfo.renderArea.offset = .{ .x = 0, .y = 0 };
        renderpassbegininfo.renderArea.extent = self.swapchainextent;
        var clearcolor: [2]vk.VkClearValue = undefined;
        clearcolor[0].color = vk.VkClearColorValue{ .int32 = .{ 0, 0, 0, 0 } };
        clearcolor[1].depthStencil = vk.VkClearDepthStencilValue{ .depth = 1, .stencil = 0 };
        renderpassbegininfo.clearValueCount = clearcolor.len;
        renderpassbegininfo.pClearValues = &clearcolor[0];

        vk.vkCmdBeginRenderPass(commandbuffer, &renderpassbegininfo, vk.VK_SUBPASS_CONTENTS_INLINE);

        vk.vkCmdBindPipeline(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicspipeline);

        var viewport: vk.VkViewport = .{};
        viewport.x = 0;
        viewport.y = 0;
        viewport.height = @floatFromInt(self.swapchainextent.height);
        viewport.width = @floatFromInt(self.swapchainextent.width);
        viewport.minDepth = 0;
        viewport.maxDepth = 1;
        vk.vkCmdSetViewport(commandbuffer, 0, 1, &viewport);

        var scissor: vk.VkRect2D = .{};
        scissor.offset = .{ .x = 0, .y = 0 };
        scissor.extent = self.swapchainextent;
        vk.vkCmdSetScissor(commandbuffer, 0, 1, &scissor);

        const vertexbuffers: [1]vk.VkBuffer = .{self.vertexbuffer};
        const offsets: [1]vk.VkDeviceSize = .{0};
        vk.vkCmdBindVertexBuffers(commandbuffer, 0, 1, &vertexbuffers[0], &offsets[0]);
        vk.vkCmdBindIndexBuffer(commandbuffer, self.indexbuffer, 0, vk.VK_INDEX_TYPE_UINT32);
        vk.vkCmdBindDescriptorSets(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipelinelayout, 0, 1, &self.descriptorsets[imageindex], 0, null);

        vk.vkCmdDrawIndexed(commandbuffer, drawing.indices.len, 1, 0, 0, 0);

        vk.vkCmdEndRenderPass(commandbuffer);

        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbuffer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
    }

    pub fn recreateswapchains(self: *graphicalcontext) !void {
        const oldswapchain: vk.VkSwapchainKHR = self.swapchain;
        const swapchainimageslen = self.swapchainimages.len;
        try createswapchain(self, oldswapchain);
        _ = vk.vkDeviceWaitIdle(self.device);
        destroydepthresources(self);
        destroyswapchainimages(self);
        destroyimageviews(self);
        vk.vkDestroyRenderPass(self.device, self.renderpass, null);
        destroyframebuffers(self);
        freeswapchain(self, oldswapchain);
        try getswapchainImages(self);
        try createimageviews(self);
        try createdepthresources(self);
        try createrenderpass(self);
        try createframebuffers(self);
        if (swapchainimageslen != self.swapchainimages.len) @panic("swap chain image length mismatch After Recreation");
    }
    fn destroydepthresources(self: *graphicalcontext) void {
        vk.vkDestroyImageView(self.device, self.depthimageview, null);
        vk.vkDestroyImage(self.device, self.depthimage, null);
        vk.vkFreeMemory(self.device, self.depthimagememory, null);
    }
    fn createdepthresources(self: *graphicalcontext) !void {
        const depthformat: vk.VkFormat = try self.finddepthformat();
        try createimage(
            self,
            self.device,
            self.swapchainextent.width,
            self.swapchainextent.height,
            depthformat,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.depthimage,
            &self.depthimagememory,
        );
        try createimageview(
            self,
            self.depthimage,
            &self.depthimageview,
            depthformat,
            vk.VK_IMAGE_ASPECT_DEPTH_BIT,
        );
        try transitionimagelayout(
            self,
            self.depthimage,
            depthformat,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        );
    }

    fn finddepthformat(self: *graphicalcontext) !vk.VkFormat {
        var formats: [3]vk.VkFormat = .{ vk.VK_FORMAT_D32_SFLOAT, vk.VK_FORMAT_D32_SFLOAT_S8_UINT, vk.VK_FORMAT_D24_UNORM_S8_UINT };
        return findsupportedformats(
            self,
            &formats,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
        );
    }
    fn findsupportedformats(self: *graphicalcontext, formatcanadates: []vk.VkFormat, tiling: vk.VkImageTiling, features: vk.VkFormatFeatureFlags) !vk.VkFormat {
        for (formatcanadates) |format| {
            var properties: vk.VkFormatProperties = undefined;
            vk.vkGetPhysicalDeviceFormatProperties(self.physicaldevice, format, &properties);
            if (tiling == vk.VK_IMAGE_TILING_LINEAR and ((properties.linearTilingFeatures & features) == features)) {
                return format;
            } else if (tiling == vk.VK_IMAGE_TILING_OPTIMAL and ((properties.optimalTilingFeatures & features) == features)) {
                return format;
            }
        }
        std.log.err("Unable to Find supported format", .{});
        return error.FailedToFindSupportedImageFormat;
    }
    fn checkstencilcomponent(format: vk.VkFormat) bool {
        return (format == vk.VK_FORMAT_D32_SFLOAT_S8_UINT or format == vk.VK_FORMAT_D24_UNORM_S8_UINT);
    }
    fn createtextureimagesampler(self: *graphicalcontext) !void {
        var samplercreateinfo: vk.VkSamplerCreateInfo = .{};
        samplercreateinfo.sType = vk.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        samplercreateinfo.magFilter = vk.VK_FILTER_LINEAR;
        samplercreateinfo.minFilter = vk.VK_FILTER_LINEAR;
        samplercreateinfo.addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplercreateinfo.addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplercreateinfo.addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplercreateinfo.anisotropyEnable = self.physicaldevicefeatures.samplerAnisotropy;
        samplercreateinfo.maxAnisotropy = self.physicaldeviceproperties.limits.maxSamplerAnisotropy;
        samplercreateinfo.borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK;
        samplercreateinfo.unnormalizedCoordinates = vk.VK_FALSE;
        samplercreateinfo.compareEnable = vk.VK_FALSE;
        samplercreateinfo.compareOp = vk.VK_COMPARE_OP_ALWAYS;
        samplercreateinfo.mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR;
        samplercreateinfo.mipLodBias = 0;
        samplercreateinfo.minLod = 0;
        samplercreateinfo.maxLod = 0;

        if (vk.vkCreateSampler(self.device, &samplercreateinfo, null, &self.textureimagesampler) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Image sampler for Texture", .{});
            return error.FailedToCreateTextureImageSampler;
        }
    }
    fn destroytextureimagesampler(self: *graphicalcontext) void {
        vk.vkDestroySampler(self.device, self.textureimagesampler, null);
    }
    fn createtextureimageview(self: *graphicalcontext) !void {
        try self.createimageview(self.textureimage, &self.textureimageview, vk.VK_FORMAT_R8G8B8A8_SRGB, vk.VK_IMAGE_ASPECT_COLOR_BIT);
    }
    fn destroytextureimageview(self: *graphicalcontext) void {
        self.destroyimageview(self.textureimageview);
    }
    //TODO create seperare funciton for loading image
    fn user_error_fn(pngptr: png.png_structp, error_msg: [*c]const u8) callconv(.c) void {
        std.log.err("Libpng error: {s}", .{std.mem.span(error_msg)});
        const errorlibpng: *u8 = @ptrCast(png.png_get_error_ptr(pngptr));
        errorlibpng.* = 1;
    }

    fn user_warning_fn(_: png.png_structp, warning_msg: [*c]const u8) callconv(.c) void {
        std.log.warn("Libpng warning: {s}", .{std.mem.span(warning_msg)});
    }

    fn createtextureimage(self: *graphicalcontext) !void {
        const dir = std.c.fopen("resources/green.png", "rb");
        var errorlibpng: ?u8 = 0;
        if (dir == null) {
            std.log.err("unable to open texture file", .{});
            return error.UnableToOpenTextureFile;
        }
        defer _ = std.c.fclose(dir.?);
        var header: [8]u8 = undefined;
        const result = std.c.fread(&header, 1, header.len, dir.?);
        if (header.len != result) {
            std.log.err("unable to Read texture file", .{});
            return error.UnableToReadTextureFile;
        }
        const is_png = png.png_sig_cmp(&header[0], 0, header.len);
        if (is_png != 0) {
            std.log.err("The file signature dosent match a png", .{});
            return error.FileNotPng;
        }
        var pngptr: png.png_structp = png.png_create_read_struct(
            png.PNG_LIBPNG_VER_STRING,
            @ptrCast(&errorlibpng),
            user_error_fn,
            user_warning_fn,
        );
        if (pngptr == null) {
            std.log.err("unable to Create png pointer", .{});
            return error.UnableToCreatePngptr;
        }
        var pnginfoptr: png.png_infop = png.png_create_info_struct(pngptr);
        if (pnginfoptr == null) {
            std.log.err("unable to Create png info pointer", .{});
            png.png_destroy_read_struct(&pngptr, null, null);
            return error.UnableToCreatePngInfoptr;
        }
        var pngendinfoptr: png.png_infop = png.png_create_info_struct(pngptr);
        if (pngendinfoptr == null) {
            std.log.err("unable to Create png end info pointer", .{});
            png.png_destroy_read_struct(&pngptr, &pnginfoptr, null);
            return error.UnableToCreatePngEndInfoptr;
        }

        defer png.png_destroy_read_struct(&pngptr, &pnginfoptr, &pngendinfoptr);

        png.png_init_io(pngptr, @ptrCast(dir));
        png.png_set_sig_bytes(pngptr, header.len);
        png.png_read_info(pngptr, pnginfoptr);

        png.png_set_expand(pngptr);
        png.png_set_strip_16(pngptr);
        png.png_set_palette_to_rgb(pngptr);
        png.png_set_gray_to_rgb(pngptr);
        png.png_set_add_alpha(pngptr, 0xFF, png.PNG_FILLER_AFTER);

        const width = png.png_get_image_width(pngptr, pnginfoptr);
        const height = png.png_get_image_height(pngptr, pnginfoptr);
        //const rowbytes = png.png_get_rowbytes(pngptr, pnginfoptr);

        const pixels: []u8 = try self.allocator.alloc(u8, height * width * 4);
        defer self.allocator.free(pixels);
        const rows: []png.png_bytep = try self.allocator.alloc(png.png_bytep, height);
        defer self.allocator.free(rows);
        for (0..height) |i| {
            rows[i] = &pixels[i * width * 4];
        }
        png.png_read_image(pngptr, &rows[0]);

        const imagesize: vk.VkDeviceSize = height * width * 4;

        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try createbuffer(
            self,
            imagesize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );

        var memdata: ?*anyopaque = undefined;
        _ = vk.vkMapMemory(self.device, stagingbuffermemory, 0, imagesize, 0, &memdata);
        const ptr: [*]u8 = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(u8, ptr[0..pixels.len], pixels);
        _ = vk.vkUnmapMemory(self.device, stagingbuffermemory);

        try createimage(
            self,
            self.device,
            width,
            height,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vk.VK_IMAGE_USAGE_SAMPLED_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.textureimage,
            &self.textureimagememory,
        );
        try self.transitionimagelayout(
            self.textureimage,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        );
        try self.copybuffertoimage(
            stagingbuffer,
            self.textureimage,
            width,
            height,
        );
        try self.transitionimagelayout(
            self.textureimage,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        );
        vk.vkDestroyBuffer(self.device, stagingbuffer, null);
        vk.vkFreeMemory(self.device, stagingbuffermemory, null);
    }
    fn destroyimage(self: *graphicalcontext, image: vk.VkImage, imagememory: vk.VkDeviceMemory) void {
        vk.vkDestroyImage(self.device, image, null);
        vk.vkFreeMemory(self.device, imagememory, null);
    }
    fn createimage(
        self: *graphicalcontext,
        device: vk.VkDevice,
        width: u32,
        height: u32,
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
        imagecreateinfo.mipLevels = 1;
        imagecreateinfo.arrayLayers = 1;
        imagecreateinfo.format = format;
        imagecreateinfo.tiling = tiling;
        imagecreateinfo.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        imagecreateinfo.usage = imageusage;
        imagecreateinfo.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
        imagecreateinfo.samples = vk.VK_SAMPLE_COUNT_1_BIT;
        imagecreateinfo.flags = 0;
        if (vk.vkCreateImage(device, &imagecreateinfo, null, image) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Texture Image", .{});
            return error.FailedToCreateTextureImage;
        }

        var memoryrequirements: vk.VkMemoryRequirements = .{};
        vk.vkGetImageMemoryRequirements(device, image.*, &memoryrequirements);

        var allocationinfo: vk.VkMemoryAllocateInfo = .{};
        allocationinfo.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocationinfo.allocationSize = memoryrequirements.size;
        allocationinfo.memoryTypeIndex = try findmemorytype(self, memoryrequirements.memoryTypeBits, memproperties);
        if (vk.vkAllocateMemory(device, &allocationinfo, null, imagememory) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Texture Image Memory", .{});
            return error.FailedToCreateTextureImageMemory;
        }
        _ = vk.vkBindImageMemory(device, image.*, imagememory.*, 0);
    }
    fn copybuffertoimage(self: *graphicalcontext, buffer: vk.VkBuffer, image: vk.VkImage, width: u32, height: u32) !void {
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands();

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
        try self.endsingletimecommands(commandbuffer);
    }
    fn transitionimagelayout(self: *graphicalcontext, image: vk.VkImage, format: vk.VkFormat, oldlayout: vk.VkImageLayout, newlayout: vk.VkImageLayout) !void {
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands();
        var barrier: vk.VkImageMemoryBarrier = .{};
        barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = oldlayout;
        barrier.newLayout = newlayout;
        barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        barrier.image = image;
        barrier.subresourceRange.baseMipLevel = 0;
        barrier.subresourceRange.levelCount = 1;
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

        try self.endsingletimecommands(commandbuffer);
    }
    fn createdescriptorpool(self: *graphicalcontext) !void {
        var descriptorpoolsizes: [2]vk.VkDescriptorPoolSize = undefined;
        descriptorpoolsizes[0].type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        descriptorpoolsizes[0].descriptorCount = @intCast(self.swapchainimages.len);
        descriptorpoolsizes[1].type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        descriptorpoolsizes[1].descriptorCount = @intCast(self.swapchainimages.len);

        var poolcreateinfo: vk.VkDescriptorPoolCreateInfo = .{};
        poolcreateinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        poolcreateinfo.poolSizeCount = @intCast(descriptorpoolsizes.len);
        poolcreateinfo.pPoolSizes = &descriptorpoolsizes[0];
        poolcreateinfo.maxSets = @intCast(self.swapchainimages.len);

        if (vk.vkCreateDescriptorPool(self.device, &poolcreateinfo, null, &self.descriptorpool) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Pool", .{});
            return error.FailedToCreateDescriptorPool;
        }
    }
    fn destroydescriptorpool(self: *graphicalcontext) void {
        vk.vkDestroyDescriptorPool(self.device, self.descriptorpool, null);
    }
    fn createdescriptorSets(self: *graphicalcontext) !void {
        var descriptorsetlayouts: []vk.VkDescriptorSetLayout = try self.allocator.alloc(vk.VkDescriptorSetLayout, self.swapchainimages.len);
        defer self.allocator.free(descriptorsetlayouts);
        for (0..self.swapchainimages.len) |i| {
            descriptorsetlayouts[i] = self.descriptorsetlayout;
        }
        self.descriptorsets = try self.allocator.alloc(vk.VkDescriptorSet, self.swapchainimages.len);

        var descriptorsetallocinfo: vk.VkDescriptorSetAllocateInfo = .{};
        descriptorsetallocinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        descriptorsetallocinfo.descriptorPool = self.descriptorpool;
        descriptorsetallocinfo.descriptorSetCount = @intCast(self.swapchainimages.len);
        descriptorsetallocinfo.pSetLayouts = &descriptorsetlayouts[0];

        if (vk.vkAllocateDescriptorSets(self.device, &descriptorsetallocinfo, &self.descriptorsets[0]) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Sets", .{});
            return error.FailedToCreateDescriptorSets;
        }
        for (0..self.swapchainimages.len) |i| {
            var bufferinfo: vk.VkDescriptorBufferInfo = .{};
            bufferinfo.buffer = self.uniformbuffer[i];
            bufferinfo.offset = 0;
            bufferinfo.range = @sizeOf(drawing.uniformbufferobject);

            var imageinfo: vk.VkDescriptorImageInfo = .{};
            imageinfo.imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            imageinfo.imageView = self.textureimageview;
            imageinfo.sampler = self.textureimagesampler;

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

            vk.vkUpdateDescriptorSets(self.device, writedescriptorset.len, &writedescriptorset[0], 0, null);
        }
    }
    fn destroydescriptorSets(self: *graphicalcontext) void {
        self.allocator.free(self.descriptorsets);
    }
    fn createdescriptorsetlayout(self: *graphicalcontext) !void {
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

        var bindings: [2]vk.VkDescriptorSetLayoutBinding = .{ ubolayoutbinding, samplerlayoutbinding };
        var layoutcreateinfo: vk.VkDescriptorSetLayoutCreateInfo = .{};
        layoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        layoutcreateinfo.bindingCount = @intCast(bindings.len);
        layoutcreateinfo.pBindings = &bindings[0];

        if (vk.vkCreateDescriptorSetLayout(self.device, &layoutcreateinfo, null, &self.descriptorsetlayout) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Set Layout", .{});
            return error.FailedToCreateDescriptorSetLayout;
        }
    }
    fn destroydescriptorsetlayout(self: *graphicalcontext) void {
        vk.vkDestroyDescriptorSetLayout(self.device, self.descriptorsetlayout, null);
    }
    fn createuniformbuffers(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.uniformbufferobject);
        const count = self.swapchainimages.len;
        self.uniformbuffer = try self.allocator.alloc(vk.VkBuffer, count);
        self.uniformbuffermemory = try self.allocator.alloc(vk.VkDeviceMemory, count);
        self.uniformbuffermemotymapped = try self.allocator.alloc(?*anyopaque, count);
        for (0..count) |i| {
            try createbuffer(
                self,
                buffersize,
                vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                &self.uniformbuffer[i],
                &self.uniformbuffermemory[i],
            );
            _ = vk.vkMapMemory(self.device, self.uniformbuffermemory[i], 0, buffersize, 0, &self.uniformbuffermemotymapped[i]);
        }
    }
    fn destroyuniformbuffers(self: *graphicalcontext) void {
        for (0..self.uniformbuffer.len) |i| {
            vk.vkDestroyBuffer(self.device, self.uniformbuffer[i], null);
            vk.vkFreeMemory(self.device, self.uniformbuffermemory[i], null);
        }
        self.allocator.free(self.uniformbuffer);
        self.allocator.free(self.uniformbuffermemory);
        self.allocator.free(self.uniformbuffermemotymapped);
    }
    fn createindexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(u32) * drawing.indices.len;
        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try createbuffer(
            self,
            buffersize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );

        var memdata: ?*anyopaque = undefined;
        _ = vk.vkMapMemory(self.device, stagingbuffermemory, 0, buffersize, 0, &memdata);
        const ptr: [*]u32 = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(u32, ptr[0..drawing.indices.len], &drawing.indices);
        _ = vk.vkUnmapMemory(self.device, stagingbuffermemory);

        try createbuffer(
            self,
            buffersize,
            vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.indexbuffer,
            &self.indexbuffermemory,
        );
        try copybuffer(self, stagingbuffer, self.indexbuffer, buffersize);
        vk.vkDestroyBuffer(self.device, stagingbuffer, null);
        vk.vkFreeMemory(self.device, stagingbuffermemory, null);
    }
    fn destroyindexbuffer(self: *graphicalcontext) void {
        vk.vkDestroyBuffer(self.device, self.indexbuffer, null);
        vk.vkFreeMemory(self.device, self.indexbuffermemory, null);
    }
    fn beginsingletimecommands(self: *graphicalcontext) !vk.VkCommandBuffer {
        _ = vk.vkWaitForFences(
            self.device,
            1,
            &self.temperorycommandbufferinuse,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        _ = vk.vkResetFences(self.device, 1, &self.temperorycommandbufferinuse);

        var cmdbufferallocateinfo: vk.VkCommandBufferAllocateInfo = .{};
        cmdbufferallocateinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cmdbufferallocateinfo.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        cmdbufferallocateinfo.commandPool = self.commandpoolonetimecommand;
        cmdbufferallocateinfo.commandBufferCount = 1;

        var commandbuffer: vk.VkCommandBuffer = undefined;
        if (vk.vkAllocateCommandBuffers(self.device, &cmdbufferallocateinfo, &commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command buffer", .{});
            return error.CommandBufferAllocationFailed;
        }

        var begininfo: vk.VkCommandBufferBeginInfo = .{};
        begininfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        begininfo.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

        if (vk.vkBeginCommandBuffer(commandbuffer, &begininfo) != vk.VK_SUCCESS) {
            std.log.err("Unable to Begin Recording Commandbufffer datatransfer", .{});
            return error.FailedToBeginRecordingCommandBuffer;
        }
        return commandbuffer;
    }
    fn endsingletimecommands(self: *graphicalcontext, commandbuffer: vk.VkCommandBuffer) !void {
        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbufffer datatransfer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
        var submitinfo: vk.VkSubmitInfo = .{};
        submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitinfo.commandBufferCount = 1;
        submitinfo.pCommandBuffers = &commandbuffer;

        if (vk.vkQueueSubmit(self.graphicsqueue.queue, 1, &submitinfo, self.temperorycommandbufferinuse) != vk.VK_SUCCESS) {
            std.log.err("Unable to Submit Queue", .{});
            return error.QueueSubmissionFailed;
        }
        _ = vk.vkWaitForFences(
            self.device,
            1,
            &self.temperorycommandbufferinuse,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        vk.vkFreeCommandBuffers(self.device, self.commandpoolonetimecommand, 1, &commandbuffer);
    }
    fn copybuffer(self: *graphicalcontext, srcbuffer: vk.VkBuffer, dstbuffer: vk.VkBuffer, size: vk.VkDeviceSize) !void {
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands();
        var copyregion: vk.VkBufferCopy = .{};
        copyregion.srcOffset = 0;
        copyregion.dstOffset = 0;
        copyregion.size = size;
        vk.vkCmdCopyBuffer(commandbuffer, srcbuffer, dstbuffer, 1, &copyregion);
        try self.endsingletimecommands(commandbuffer);
    }
    fn createvertexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.data) * drawing.vertices.len;
        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try createbuffer(
            self,
            buffersize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );

        var memdata: ?*anyopaque = undefined;
        _ = vk.vkMapMemory(self.device, stagingbuffermemory, 0, buffersize, 0, &memdata);
        const ptr: [*]drawing.data = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(drawing.data, ptr[0..drawing.vertices.len], &drawing.vertices);
        _ = vk.vkUnmapMemory(self.device, stagingbuffermemory);

        try createbuffer(
            self,
            buffersize,
            vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.vertexbuffer,
            &self.vertexbuffermemory,
        );
        try copybuffer(self, stagingbuffer, self.vertexbuffer, buffersize);
        vk.vkDestroyBuffer(self.device, stagingbuffer, null);
        vk.vkFreeMemory(self.device, stagingbuffermemory, null);
    }
    fn destroyvertexbuffer(self: *graphicalcontext) void {
        vk.vkDestroyBuffer(self.device, self.vertexbuffer, null);
        vk.vkFreeMemory(self.device, self.vertexbuffermemory, null);
    }
    fn createbuffer(
        self: *graphicalcontext,
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
        if (vk.vkCreateBuffer(self.device, &buffercreateinfo, null, buffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to create vertex buffer", .{});
            return error.FailedToCreateVertexBuffer;
        }

        var memoryrequirements: vk.VkMemoryRequirements = .{};
        vk.vkGetBufferMemoryRequirements(self.device, buffer.*, &memoryrequirements);

        var allocationinfo: vk.VkMemoryAllocateInfo = .{};
        allocationinfo.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocationinfo.allocationSize = memoryrequirements.size;
        allocationinfo.memoryTypeIndex = try findmemorytype(
            self,
            memoryrequirements.memoryTypeBits,
            memorypropertiesflags,
        );
        if (vk.vkAllocateMemory(self.device, &allocationinfo, null, buffermemory) != vk.VK_SUCCESS) {
            std.log.err("Unable to Allocate Gpu Memory", .{});
            return error.FailedToAllocateGpuMemory;
        }
        _ = vk.vkBindBufferMemory(self.device, buffer.*, buffermemory.*, 0);
    }
    fn findmemorytype(self: *graphicalcontext, typefilter: u32, properties: vk.VkMemoryPropertyFlags) !u32 {
        var memoryproperties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physicaldevice, &memoryproperties);
        for (0..memoryproperties.memoryTypeCount) |i| {
            if ((typefilter & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0 and (memoryproperties.memoryTypes[i].propertyFlags & properties) != 0) {
                return @intCast(i);
            }
            if (i == std.math.maxInt(u5)) break;
        }
        std.log.err("Unable to find suitable memory type", .{});
        return error.FailedToFindSuitableMemory;
    }

    fn destroysyncobjects(self: *graphicalcontext) void {
        for (0..self.swapchainimages.len) |i| {
            vk.vkDestroySemaphore(self.device, self.imageavailablesephamores[i], null);
            vk.vkDestroySemaphore(self.device, self.renderfinishedsephamores[i], null);
            vk.vkDestroyFence(self.device, self.inflightfences[i], null);
        }
        vk.vkDestroyFence(self.device, self.temperorycommandbufferinuse, null);
        self.allocator.free(self.imageavailablesephamores);
        self.allocator.free(self.renderfinishedsephamores);
        self.allocator.free(self.inflightfences);
    }
    fn createsyncobjects(self: *graphicalcontext) !void {
        var sephamorecreateinfo: vk.VkSemaphoreCreateInfo = .{};
        sephamorecreateinfo.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        var fencecreateinfo: vk.VkFenceCreateInfo = .{};
        fencecreateinfo.sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fencecreateinfo.flags = vk.VK_FENCE_CREATE_SIGNALED_BIT;
        self.imageavailablesephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchainimages.len);
        self.renderfinishedsephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchainimages.len);
        self.inflightfences = try self.allocator.alloc(vk.VkFence, self.swapchainimages.len);
        for (0..self.swapchainimages.len) |i| {
            if (vk.vkCreateSemaphore(self.device, &sephamorecreateinfo, null, &self.imageavailablesephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
            if (vk.vkCreateSemaphore(self.device, &sephamorecreateinfo, null, &self.renderfinishedsephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
            if (vk.vkCreateFence(self.device, &fencecreateinfo, null, &self.inflightfences[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Cpu fence (render)", .{});
                return error.UnableToCreateFence;
            }
        }
        if (vk.vkCreateFence(self.device, &fencecreateinfo, null, &self.temperorycommandbufferinuse) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Cpu fence (datatransfer)", .{});
            return error.UnableToCreateFence;
        }
    }

    fn createcommandbuffer(self: *graphicalcontext) !void {
        self.commandbuffers = try self.allocator.alloc(vk.VkCommandBuffer, self.swapchainimages.len);
        var allocinfo: vk.VkCommandBufferAllocateInfo = .{};
        allocinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocinfo.commandPool = self.commandpool;
        allocinfo.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        allocinfo.commandBufferCount = 1;
        for (0..self.swapchainimages.len) |i| {
            if (vk.vkAllocateCommandBuffers(self.device, &allocinfo, &self.commandbuffers[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to create Command buffer", .{});
                return error.CommandBufferAllocationFailed;
            }
        }
    }
    fn createcommandpools(self: *graphicalcontext) !void {
        var commandpoolcreateinfo: vk.VkCommandPoolCreateInfo = .{};
        commandpoolcreateinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        commandpoolcreateinfo.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        commandpoolcreateinfo.queueFamilyIndex = self.graphicsqueue.familyindex;

        if (vk.vkCreateCommandPool(self.device, &commandpoolcreateinfo, null, &self.commandpool) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command Pool", .{});
            return error.CommandPoolCreationFailed;
        }

        var commandpooldatatransfercreateinfo: vk.VkCommandPoolCreateInfo = .{};
        commandpooldatatransfercreateinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        commandpooldatatransfercreateinfo.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT | vk.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT;
        commandpooldatatransfercreateinfo.queueFamilyIndex = self.graphicsqueue.familyindex;

        if (vk.vkCreateCommandPool(self.device, &commandpooldatatransfercreateinfo, null, &self.commandpoolonetimecommand) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command Pool", .{});
            return error.CommandPoolCreationFailed;
        }
    }
    fn destroycommandpools(self: *graphicalcontext) void {
        vk.vkDestroyCommandPool(self.device, self.commandpool, null);
        vk.vkDestroyCommandPool(self.device, self.commandpoolonetimecommand, null);
    }
    fn destroyframebuffers(self: *graphicalcontext) void {
        for (0..self.swapchainframebuffers.len) |i| {
            vk.vkDestroyFramebuffer(self.device, self.swapchainframebuffers[i], null);
        }
        self.allocator.free(self.swapchainframebuffers);
    }
    fn createframebuffers(self: *graphicalcontext) !void {
        self.swapchainframebuffers = try self.allocator.alloc(vk.VkFramebuffer, self.swapchainimageviews.len);

        for (0..self.swapchainimageviews.len) |i| {
            var attachments: [2]vk.VkImageView = .{ self.swapchainimageviews[i], self.depthimageview };
            var framebuffercreateinfo: vk.VkFramebufferCreateInfo = .{};
            framebuffercreateinfo.sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            framebuffercreateinfo.renderPass = self.renderpass;
            framebuffercreateinfo.attachmentCount = attachments.len;
            framebuffercreateinfo.pAttachments = &attachments[0];
            framebuffercreateinfo.width = self.swapchainextent.width;
            framebuffercreateinfo.height = self.swapchainextent.height;
            framebuffercreateinfo.layers = 1;
            if (vk.vkCreateFramebuffer(self.device, &framebuffercreateinfo, null, &self.swapchainframebuffers[i]) != vk.VK_SUCCESS) {
                std.log.err("Failed To create frame buffer", .{});
                return error.FrameBufferCreationFailed;
            }
        }
    }
    fn createrenderpass(self: *graphicalcontext) !void {
        var colorattachment: vk.VkAttachmentDescription = .{};
        colorattachment.format = self.swapchainimageformat;
        colorattachment.samples = vk.VK_SAMPLE_COUNT_1_BIT;
        colorattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
        colorattachment.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        colorattachment.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
        colorattachment.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        colorattachment.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        var depthattachment: vk.VkAttachmentDescription = .{};
        depthattachment.format = try self.finddepthformat();
        depthattachment.samples = vk.VK_SAMPLE_COUNT_1_BIT;
        depthattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        depthattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
        depthattachment.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        depthattachment.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
        depthattachment.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        depthattachment.finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

        var colorattachmentrefrence: vk.VkAttachmentReference = .{};
        colorattachmentrefrence.attachment = 0;
        colorattachmentrefrence.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        var depthattachmentrefrence: vk.VkAttachmentReference = .{};
        depthattachmentrefrence.attachment = 1;
        depthattachmentrefrence.layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

        var subpass: vk.VkSubpassDescription = .{};
        subpass.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = &colorattachmentrefrence;
        subpass.pDepthStencilAttachment = &depthattachmentrefrence;

        var subpassdependency: vk.VkSubpassDependency = .{};
        subpassdependency.srcSubpass = vk.VK_SUBPASS_EXTERNAL;
        subpassdependency.dstSubpass = 0;
        subpassdependency.srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
        subpassdependency.srcAccessMask = 0;
        subpassdependency.dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
        subpassdependency.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

        var attachments: [2]vk.VkAttachmentDescription = .{ colorattachment, depthattachment };
        var renderpasscreateinfo: vk.VkRenderPassCreateInfo = .{};
        renderpasscreateinfo.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        renderpasscreateinfo.attachmentCount = attachments.len;
        renderpasscreateinfo.pAttachments = &attachments[0];
        renderpasscreateinfo.subpassCount = 1;
        renderpasscreateinfo.pSubpasses = &subpass;
        renderpasscreateinfo.dependencyCount = 1;
        renderpasscreateinfo.pDependencies = &subpassdependency;

        if (vk.vkCreateRenderPass(self.device, &renderpasscreateinfo, null, &self.renderpass) != vk.VK_SUCCESS) {
            std.log.err("Unable To create Render Pass", .{});
            return error.UnableToCreateRenderPass;
        }
    }
    fn createshadermodule(code: []const u32, self: *graphicalcontext) !vk.VkShaderModule {
        var createinfo: vk.VkShaderModuleCreateInfo = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        createinfo.codeSize = code.len * 4;
        createinfo.pCode = @ptrCast(code);

        var shadermodule: vk.VkShaderModule = undefined;
        if (vk.vkCreateShaderModule(self.device, &createinfo, null, &shadermodule) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Shader Module", .{});
            return error.ShaderModuleCreationFailed;
        }
        return shadermodule;
    }
    fn creategraphicspipeline(self: *graphicalcontext) !void {
        //cast a slice of u8 to slice of u32
        const vertcodeslice = @as([*]const u32, @ptrCast(@alignCast(triangle_vert)))[0 .. triangle_vert.len / @sizeOf(u32)];
        const fragcodeslice = @as([*]const u32, @ptrCast(@alignCast(triangle_frag)))[0 .. triangle_frag.len / @sizeOf(u32)];

        const vertshadermodule = try createshadermodule(vertcodeslice, self);
        const fragshadermodule = try createshadermodule(fragcodeslice, self);

        var vertshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
        vertshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vertshadercreateinfo.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
        vertshadercreateinfo.module = vertshadermodule;
        vertshadercreateinfo.pName = "main";

        var fragshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
        fragshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fragshadercreateinfo.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
        fragshadercreateinfo.module = fragshadermodule;
        fragshadercreateinfo.pName = "main";

        var shaderstages: [2]vk.VkPipelineShaderStageCreateInfo = .{ vertshadercreateinfo, fragshadercreateinfo };
        _ = &shaderstages;

        var dynamicstates: [2]vk.VkDynamicState = .{ vk.VK_DYNAMIC_STATE_VIEWPORT, vk.VK_DYNAMIC_STATE_SCISSOR };
        var dynamicstatecreateinfo: vk.VkPipelineDynamicStateCreateInfo = .{};
        dynamicstatecreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        dynamicstatecreateinfo.dynamicStateCount = dynamicstates.len;
        dynamicstatecreateinfo.pDynamicStates = &dynamicstates[0];

        var bindingdescription = vertexbufferconfig.getbindingdescription(drawing.data);
        var attributedescribtions = vertexbufferconfig.getattributedescruptions(drawing.data);
        //this structure describes the format of the vertex data that will be passed to the vertex shader
        var vertexinputinfo: vk.VkPipelineVertexInputStateCreateInfo = .{};
        vertexinputinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
        vertexinputinfo.vertexBindingDescriptionCount = 1;
        vertexinputinfo.pVertexBindingDescriptions = &bindingdescription;
        vertexinputinfo.vertexAttributeDescriptionCount = attributedescribtions.len;
        vertexinputinfo.pVertexAttributeDescriptions = &attributedescribtions[0];

        var inputassembly: vk.VkPipelineInputAssemblyStateCreateInfo = .{};
        inputassembly.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputassembly.topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        inputassembly.primitiveRestartEnable = vk.VK_FALSE;

        var viewport: vk.VkViewport = .{};
        viewport.x = 0;
        viewport.y = 0;
        viewport.width = @floatFromInt(self.swapchainextent.width);
        viewport.height = @floatFromInt(self.swapchainextent.height);
        viewport.minDepth = 0;
        viewport.maxDepth = 1;

        var scissor: vk.VkRect2D = .{};
        scissor.offset = .{ .x = 0, .y = 1 };
        scissor.extent = self.swapchainextent;

        var viewportstatecreateinfo: vk.VkPipelineViewportStateCreateInfo = .{};
        viewportstatecreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewportstatecreateinfo.viewportCount = 1;
        viewportstatecreateinfo.pViewports = &viewport;
        viewportstatecreateinfo.scissorCount = 1;
        viewportstatecreateinfo.pScissors = &scissor;

        var rasterizer: vk.VkPipelineRasterizationStateCreateInfo = .{};
        rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.depthBiasEnable = vk.VK_FALSE;
        rasterizer.rasterizerDiscardEnable = vk.VK_FALSE;
        rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL;
        rasterizer.lineWidth = 1;
        rasterizer.cullMode = vk.VK_CULL_MODE_BACK_BIT;
        rasterizer.frontFace = vk.VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rasterizer.depthBiasEnable = vk.VK_FALSE;
        rasterizer.depthBiasConstantFactor = 0;
        rasterizer.depthBiasClamp = 0;
        rasterizer.depthBiasSlopeFactor = 0;

        var multisampling: vk.VkPipelineMultisampleStateCreateInfo = .{};
        multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.sampleShadingEnable = vk.VK_FALSE;
        multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;
        multisampling.minSampleShading = 1;
        multisampling.pSampleMask = null;
        multisampling.alphaToCoverageEnable = vk.VK_FALSE;
        multisampling.alphaToOneEnable = vk.VK_FALSE;

        var depthstencil: vk.VkPipelineDepthStencilStateCreateInfo = .{};
        depthstencil.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
        depthstencil.depthTestEnable = vk.VK_TRUE;
        depthstencil.depthWriteEnable = vk.VK_TRUE;
        depthstencil.depthCompareOp = vk.VK_COMPARE_OP_LESS;
        depthstencil.depthBoundsTestEnable = vk.VK_FALSE;
        depthstencil.minDepthBounds = 0;
        depthstencil.maxDepthBounds = 1;
        depthstencil.stencilTestEnable = vk.VK_FALSE;
        depthstencil.front = .{};
        depthstencil.back = .{};

        var colorblendattachment: vk.VkPipelineColorBlendAttachmentState = .{};
        colorblendattachment.colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT;
        colorblendattachment.blendEnable = vk.VK_FALSE;
        colorblendattachment.srcColorBlendFactor = vk.VK_BLEND_FACTOR_ONE;
        colorblendattachment.dstColorBlendFactor = vk.VK_BLEND_FACTOR_ZERO;
        colorblendattachment.colorBlendOp = vk.VK_BLEND_OP_ADD;
        colorblendattachment.srcAlphaBlendFactor = vk.VK_BLEND_FACTOR_ONE;
        colorblendattachment.dstAlphaBlendFactor = vk.VK_BLEND_FACTOR_ZERO;
        colorblendattachment.alphaBlendOp = vk.VK_BLEND_OP_ADD;

        var colourblendcreateinfo: vk.VkPipelineColorBlendStateCreateInfo = .{};
        colourblendcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        colourblendcreateinfo.logicOpEnable = vk.VK_FALSE;
        colourblendcreateinfo.logicOp = vk.VK_LOGIC_OP_COPY;
        colourblendcreateinfo.attachmentCount = 1;
        colourblendcreateinfo.pAttachments = &colorblendattachment;
        colourblendcreateinfo.blendConstants[0] = 0;
        colourblendcreateinfo.blendConstants[1] = 0;
        colourblendcreateinfo.blendConstants[2] = 0;
        colourblendcreateinfo.blendConstants[3] = 0;

        var setlayouts: [1]vk.VkDescriptorSetLayout = .{self.descriptorsetlayout};
        var pipelinelayoutcreateinfo: vk.VkPipelineLayoutCreateInfo = .{};
        pipelinelayoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipelinelayoutcreateinfo.setLayoutCount = 1;
        pipelinelayoutcreateinfo.pSetLayouts = &setlayouts[0];
        pipelinelayoutcreateinfo.pushConstantRangeCount = 0;
        pipelinelayoutcreateinfo.pPushConstantRanges = null;

        if (vk.vkCreatePipelineLayout(self.device, &pipelinelayoutcreateinfo, null, &self.pipelinelayout) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Pipeline Layout", .{});
            return error.PipelineCreationFailedLayout;
        }

        var graphicspipelinecreateinfo: vk.VkGraphicsPipelineCreateInfo = .{};
        graphicspipelinecreateinfo.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        graphicspipelinecreateinfo.stageCount = shaderstages.len;
        graphicspipelinecreateinfo.pStages = &shaderstages[0];
        graphicspipelinecreateinfo.pVertexInputState = &vertexinputinfo;
        graphicspipelinecreateinfo.pInputAssemblyState = &inputassembly;
        graphicspipelinecreateinfo.pViewportState = &viewportstatecreateinfo;
        graphicspipelinecreateinfo.pRasterizationState = &rasterizer;
        graphicspipelinecreateinfo.pMultisampleState = &multisampling;
        graphicspipelinecreateinfo.pDepthStencilState = &depthstencil;
        graphicspipelinecreateinfo.pColorBlendState = &colourblendcreateinfo;
        graphicspipelinecreateinfo.pDynamicState = &dynamicstatecreateinfo;
        graphicspipelinecreateinfo.layout = self.pipelinelayout;
        graphicspipelinecreateinfo.renderPass = self.renderpass;
        graphicspipelinecreateinfo.subpass = 0;
        graphicspipelinecreateinfo.basePipelineHandle = null;
        graphicspipelinecreateinfo.basePipelineIndex = -1;

        if (vk.vkCreateGraphicsPipelines(self.device, null, 1, &graphicspipelinecreateinfo, null, &self.graphicspipeline) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Pipeline", .{});
            return error.PipelineCreationFailed;
        }

        vk.vkDestroyShaderModule(self.device, vertshadermodule, null);
        vk.vkDestroyShaderModule(self.device, fragshadermodule, null);
    }
    fn createimageviews(self: *graphicalcontext) !void {
        self.swapchainimageviews = try self.allocator.alloc(vk.VkImageView, self.swapchainimages.len);
        for (0..self.swapchainimageviews.len) |i| {
            try self.createimageview(self.swapchainimages[i], &self.swapchainimageviews[i], self.swapchainimageformat, vk.VK_IMAGE_ASPECT_COLOR_BIT);
        }
    }
    fn createimageview(self: *graphicalcontext, image: vk.VkImage, imageview: *vk.VkImageView, format: vk.VkFormat, aspectflags: vk.VkImageAspectFlags) !void {
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
        createinfo.subresourceRange.levelCount = 1;
        createinfo.subresourceRange.baseArrayLayer = 0;
        createinfo.subresourceRange.layerCount = 1;

        if (vk.vkCreateImageView(self.device, &createinfo, null, imageview) != vk.VK_SUCCESS) {
            std.log.err("Failed to Create image Views", .{});
            return error.FailedToCreateImageView;
        }
    }

    fn destroyimageviews(self: *graphicalcontext) void {
        for (self.swapchainimageviews) |imageview| {
            self.destroyimageview(imageview);
        }
        self.allocator.free(self.swapchainimageviews);
    }
    fn destroyimageview(self: *graphicalcontext, imageview: vk.VkImageView) void {
        vk.vkDestroyImageView(self.device, imageview, null);
    }
    fn createswapchain(self: *graphicalcontext, oldswapchain: vk.VkSwapchainKHR) !void {
        const swapchainsprt: *swapchainsupport = try swapchainsupport.getSwapchainDetails(self, self.physicaldevice);
        defer swapchainsprt.deinit();
        const surfaceformat: vk.VkSurfaceFormatKHR = try swapchainsprt.chooseformat();
        self.swapchainimageformat = surfaceformat.format;
        const presentmode: vk.VkPresentModeKHR = swapchainsprt.choosepresentmode();
        const extent: vk.VkExtent2D = swapchainsprt.chooseswapextent();
        self.swapchainextent = extent;
        var imagecount: u32 = swapchainsprt.capabilities.minImageCount + 1;
        if (swapchainsprt.capabilities.maxImageCount > 0 and imagecount > swapchainsprt.capabilities.maxImageCount) {
            imagecount = swapchainsprt.capabilities.maxImageCount;
        }
        var createinfo: vk.VkSwapchainCreateInfoKHR = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        createinfo.surface = self.surface;

        createinfo.minImageCount = imagecount;
        createinfo.imageFormat = surfaceformat.format;
        createinfo.imageColorSpace = surfaceformat.colorSpace;
        createinfo.imageExtent = extent;
        createinfo.imageArrayLayers = 1;
        createinfo.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        if (self.presentqueue.familyindex != self.graphicsqueue.familyindex) {
            const queuefamilyindices: [2]u32 = .{ self.presentqueue.familyindex, self.graphicsqueue.familyindex };
            createinfo.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
            createinfo.queueFamilyIndexCount = 2;
            createinfo.pQueueFamilyIndices = &queuefamilyindices[0];
        } else {
            //use this if graphics que and present que are same
            createinfo.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
            createinfo.queueFamilyIndexCount = 0;
            createinfo.pQueueFamilyIndices = null;
        }

        createinfo.preTransform = swapchainsprt.capabilities.currentTransform;
        createinfo.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

        createinfo.presentMode = presentmode;
        createinfo.clipped = vk.VK_TRUE;

        createinfo.oldSwapchain = oldswapchain;
        if (vk.vkCreateSwapchainKHR(self.device, &createinfo, null, &self.swapchain) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Swapchain", .{});
            return error.SwapChainCreationFailed;
        }
    }
    fn getswapchainImages(self: *graphicalcontext) !void {
        var imagecount: u32 = 0;
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &imagecount, null);
        self.swapchainimages = try self.allocator.alloc(vk.VkImage, imagecount);
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &imagecount, &self.swapchainimages[0]);
    }
    fn destroyswapchainimages(self: *graphicalcontext) void {
        self.allocator.free(self.swapchainimages);
    }
    fn freeswapchain(self: *graphicalcontext, swapchain: vk.VkSwapchainKHR) void {
        vk.vkDestroySwapchainKHR(self.device, swapchain, null);
    }
    fn createsurface(self: *graphicalcontext) !void {
        if (vk.glfwCreateWindowSurface(self.instance, self.window, null, &self.surface) != vk.VK_SUCCESS) {
            std.log.err("Glfw surface creation failed", .{});
            return error.GlfwSurfaceCreationFailed;
        }
    }
    fn createlogicaldevice(self: *graphicalcontext) !void {
        self.queuelist.queueflagsmatch(vk.VK_QUEUE_GRAPHICS_BIT);
        const ques1num = self.queuelist.queuesfound;
        const ques1 = try self.allocator.dupe(u32, self.queuelist.searchresult);
        defer self.allocator.free(ques1);
        self.queuelist.checkpresentCapable(self, self.physicaldevice);
        const ques2num = self.queuelist.queuesfound;
        const ques2 = try self.allocator.dupe(u32, self.queuelist.searchresult);
        defer self.allocator.free(ques2);
        var quefamilyindex: [2]u32 = undefined;
        var uniquefound: bool = false;
        for (0..ques1num) |i| {
            for (0..ques2num) |j| {
                if (ques1[i] != ques2[j]) {
                    quefamilyindex = .{ ques1[i], ques2[j] };
                    uniquefound = true;
                }
            }
        }
        if (!uniquefound) {
            std.log.err("Unable to find unique quefamilies", .{});
            return error.UnableToFindUniqueQueueFamilyIndex;
        }
        var quecreateinfos: [quefamilyindex.len]vk.VkDeviceQueueCreateInfo = undefined;
        var quepriority: f32 = 1.0;
        for (0..quefamilyindex.len) |i| {
            quecreateinfos[i].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            quecreateinfos[i].pNext = null;
            quecreateinfos[i].flags = 0;
            quecreateinfos[i].queueFamilyIndex = quefamilyindex[i];
            quecreateinfos[i].queueCount = 1;
            quecreateinfos[i].pQueuePriorities = &quepriority;
        } //specify device features
        var physicaldevicefeatures: vk.VkPhysicalDeviceFeatures = .{};
        physicaldevicefeatures.samplerAnisotropy = self.physicaldevicefeatures.samplerAnisotropy;
        //creating logicaldevice
        var createinfo: vk.VkDeviceCreateInfo = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createinfo.pQueueCreateInfos = &quecreateinfos[0];
        createinfo.queueCreateInfoCount = quecreateinfos.len;
        createinfo.pEnabledFeatures = &physicaldevicefeatures;
        createinfo.enabledExtensionCount = @intCast(deviceextensions.len);
        createinfo.ppEnabledExtensionNames = @as([*c]const [*c]const u8, &deviceextensions[0]);

        if (enablevalidationlayers) {
            createinfo.enabledLayerCount = @intCast(validationlayers.len);
            createinfo.ppEnabledLayerNames = @as([*c]const [*c]const u8, &validationlayers[0]);
        } else {
            createinfo.enabledLayerCount = 0;
        }
        if (vk.vkCreateDevice(self.physicaldevice, &createinfo, null, &self.device) != vk.VK_SUCCESS) {
            std.log.err("unable to create logical device", .{});
            return error.FailedLogicalDeviceCreation;
        }
        vk.vkGetDeviceQueue(self.device, quefamilyindex[0], 0, &self.graphicsqueue.queue);
        self.graphicsqueue.familyindex = quefamilyindex[0];
        vk.vkGetDeviceQueue(self.device, quefamilyindex[1], 0, &self.presentqueue.queue);
        self.presentqueue.familyindex = quefamilyindex[1];
    }
    fn destroylogicaldevice(self: *graphicalcontext) void {
        vk.vkDestroyDevice(self.device, null);
    }
    fn pickphysicaldevice(self: *graphicalcontext) !void {
        var devicecount: u32 = 0;
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &devicecount, null);
        if (devicecount == 0) {
            std.log.err("unable to find gpu with vulkan support", .{});
            return error.UnableToFindGPU;
        }
        const devicelist = self.allocator.alloc(vk.VkPhysicalDevice, devicecount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan device list {s}", .{@errorName(err)});
            return err;
        };
        defer self.allocator.free(devicelist);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &devicecount, &devicelist[0]);

        const devicescorelist = self.allocator.alloc(u32, devicecount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan device score list {s}", .{@errorName(err)});
            return err;
        };
        defer self.allocator.free(devicescorelist);

        self.physicaldevice = null;
        for (0..devicecount) |i| {
            std.log.info("checking device information", .{});
            devicescorelist[i] = try ratedevicecompatability(self, devicelist[i]);
        }
        //find best device based on score
        var topscore: u32 = 0;
        var topdevice: usize = 0;
        for (0..devicecount) |i| {
            if (topscore < devicescorelist[i]) {
                topscore = devicescorelist[i];
                topdevice = @intCast(i);
            }
        }
        if (topscore > 0) {
            self.physicaldevice = devicelist[topdevice];
            vk.vkGetPhysicalDeviceProperties(self.physicaldevice, &self.physicaldeviceproperties);
            vk.vkGetPhysicalDeviceFeatures(self.physicaldevice, &self.physicaldevicefeatures);
        }
        if (self.physicaldevice == null) {
            std.log.err("Unable to find suitable Gpu", .{});
            return error.UnableToFIndSuitableGPU;
        }
    }

    fn ratedevicecompatability(self: *graphicalcontext, device: vk.VkPhysicalDevice) !u32 {
        var score: u32 = 0;
        var deviceproperties: vk.VkPhysicalDeviceProperties = .{};
        var devicefeatures: vk.VkPhysicalDeviceFeatures = .{};
        vk.vkGetPhysicalDeviceProperties(device, &deviceproperties);
        vk.vkGetPhysicalDeviceFeatures(device, &devicefeatures);

        //check device properties

        //check device features
        if (devicefeatures.samplerAnisotropy == vk.VK_TRUE) {
            score = score + 10;
        }

        //check extension
        const devicecompatibility = try checkdeviceextensionsupport(self, device);
        if (!devicecompatibility) {
            std.log.warn("Required extensions not found", .{});
            return 0;
        }

        //check swapchain
        const currentswapchain = try swapchainsupport.getSwapchainDetails(self, device);
        defer currentswapchain.deinit();
        if (currentswapchain.formatcount == 0 or currentswapchain.presentmodecount == 0) {
            std.log.warn("NO adecuuate swapchain found for device", .{});
            return 0;
        }
        //score based on available queue families
        const queuelist = try graphicsqueue.getqueuefamily(self, device);
        defer queuelist.deinit();
        queuelist.queueflagsmatch(vk.VK_QUEUE_GRAPHICS_BIT);
        if (queuelist.queuesfound > 0) score = score + 20;
        queuelist.queueflagsmatch(vk.VK_QUEUE_COMPUTE_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_TRANSFER_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_SPARSE_BINDING_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_PROTECTED_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_VIDEO_DECODE_BIT_KHR);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_VIDEO_ENCODE_BIT_KHR);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_OPTICAL_FLOW_BIT_NV);
        if (queuelist.queuesfound > 0) score = score + 10;

        return score;
    }
    fn checkdeviceextensionsupport(self: *graphicalcontext, device: vk.VkPhysicalDevice) !bool {
        var extensioncount: u32 = 0;
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extensioncount, null);
        var extensionproperties = try self.allocator.alloc(vk.VkExtensionProperties, extensioncount);
        defer self.allocator.free(extensionproperties);
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extensioncount, &extensionproperties[0]);
        var requiredestensionsavailable: bool = false;
        var extensionsfound: u32 = 0;
        for (0..deviceextensions.len) |i| {
            requiredestensionsavailable = false;
            for (0..extensioncount) |j| {
                if (std.mem.orderZ(u8, deviceextensions[i], @ptrCast(&extensionproperties[j].extensionName)) == .eq) {
                    requiredestensionsavailable = true;
                    extensionsfound = extensionsfound + 1;
                }
            }
            if (!requiredestensionsavailable) {
                std.log.err("Unable to find Required Device Extensions: {s}", .{deviceextensions[i]});
            }
        }
        std.log.info("{d}/{d} Device Extensions found", .{ extensionsfound, deviceextensions.len });
        if (extensionsfound == deviceextensions.len) {
            return true;
        } else {
            std.log.err("Unable to find Required Device Extensions", .{});
            return false;
        }
    }
    ///setup common parameters to create debug messanger
    fn setdebugmessangercreateinfo(createinfo: *vk.VkDebugUtilsMessengerCreateInfoEXT) void {
        createinfo.sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        createinfo.messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        createinfo.messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        createinfo.pfnUserCallback = debugCallback;
        createinfo.pUserData = null;
    }
    ///create an vulkan instance
    fn createinstance(self: *graphicalcontext) void {
        var appinfo: vk.VkApplicationInfo = .{};
        appinfo.sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appinfo.pApplicationName = "vulkan-zig triangle example";
        appinfo.applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0);
        appinfo.pEngineName = "No Engine";
        appinfo.engineVersion = vk.VK_MAKE_VERSION(1, 0, 0);
        appinfo.apiVersion = vk.VK_API_VERSION_1_0;

        var createinfo: vk.VkInstanceCreateInfo = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createinfo.pApplicationInfo = &appinfo;

        var extensioncount: u32 = 0;
        try getrequiredextensions(self, &extensioncount);
        const extensions_c = self.instanceextensions.extensions();
        checkextensions(self.allocator, extensioncount, extensions_c);
        createinfo.enabledExtensionCount = extensioncount;
        createinfo.ppEnabledExtensionNames = extensions_c;

        if (!checkvalidationlayersupport(self.allocator) and enablevalidationlayers) {
            @panic("unable to find validation layers");
        }
        if (enablevalidationlayers) {
            createinfo.enabledLayerCount = @intCast(validationlayers.len);
            createinfo.ppEnabledLayerNames = &validationlayers[0];

            var debugcreateInfo: vk.VkDebugUtilsMessengerCreateInfoEXT = .{};
            setdebugmessangercreateinfo(&debugcreateInfo);
            createinfo.pNext = &debugcreateInfo;
        } else {
            createinfo.enabledLayerCount = 0;
            createinfo.pNext = null;
        }
        if (vk.vkCreateInstance(&createinfo, null, &self.instance) != vk.VK_SUCCESS) {
            std.log.err("error", .{});
            @panic("failed to create instance!");
        }
    }
    ///destroy the debug messanger created via createdebugmessanger
    fn destroydebugmessanger(self: *graphicalcontext) void {
        if (!enablevalidationlayers) {
            return;
        }
        const raw = vk.vkGetInstanceProcAddr(self.instance, "vkDestroyDebugUtilsMessengerEXT");
        if (raw == null) {
            std.log.err("Unable to destroy debug messanger", .{});
        } else {
            const DestroyDebugUtilsMessengerEXT: vk.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(raw.?);
            //DestroyDebugUtilsMessengerEXT(instance, debugMessenger, *pAllocator)
            DestroyDebugUtilsMessengerEXT.?(self.instance, self.debugmessanger, null);
        }
    }
    ///create a debug messanger for vulkan validation layer
    fn createdebugmessanger(self: *graphicalcontext) !void {
        if (!enablevalidationlayers) {
            return;
        }
        const raw = vk.vkGetInstanceProcAddr(self.instance, "vkCreateDebugUtilsMessengerEXT");
        if (raw == null) {
            return error.VK_ERROR_EXTENSION_NOT_PRESENT;
        }
        const CreateDebugUtilsMessengerEXT: vk.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(raw.?);
        var debugcreateInfo: vk.VkDebugUtilsMessengerCreateInfoEXT = .{};
        setdebugmessangercreateinfo(&debugcreateInfo);
        // CreateDebugUtilsMessengerEXT(instance,*pCreateInfo,*pAllocator, *pDebugMessenger)
        if (CreateDebugUtilsMessengerEXT.?(self.instance, &debugcreateInfo, null, &self.debugmessanger) != vk.VK_SUCCESS) {
            std.log.err("failed to setup debug messager", .{});
            return error.SetupDebugMessanger;
        }
    }

    fn getrequiredextensions(self: *graphicalcontext, extensioncount: *u32) !void {
        var glfwextensioncount: u32 = 0;
        const glfwextensions = vk.glfwGetRequiredInstanceExtensions(&glfwextensioncount);

        var arrayptrs = std.ArrayList(helper.stringarrayc).init(self.allocator);
        defer arrayptrs.deinit();
        arrayptrs.append(helper.stringarrayc{ .string = @ptrCast(glfwextensions), .len = glfwextensioncount }) catch |err| {
            std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
            @panic("Memory allocation Error");
        };
        if (enablevalidationlayers) {
            var extensionlist: [2]?[*c]const u8 = .{ "VK_EXT_debug_utils", null };
            extensioncount.* = glfwextensioncount + @as(u32, @intCast(extensionlist.len - 1));
            arrayptrs.append(helper.stringarrayc{ .string = @ptrCast(&extensionlist[0]), .len = 1 }) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };
            const arr = helper.extensionarray.joinstr(
                self.allocator,
                extensioncount.*,
                &arrayptrs,
            ) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };

            self.instanceextensions = arr;
        } else {
            extensioncount.* = glfwextensioncount;
            const arr = helper.extensionarray.joinstr(
                self.allocator,
                extensioncount.*,
                &arrayptrs,
            ) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };
            self.instanceextensions = arr;
        }
    }

    fn checkvalidationlayersupport(allocator: std.mem.Allocator) bool {
        var layerCount: u32 = undefined;
        _ = vk.vkEnumerateInstanceLayerProperties(&layerCount, null);

        const availableLayer: []vk.VkLayerProperties = allocator.alloc(vk.VkLayerProperties, layerCount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan validation layer check array {s}", .{@errorName(err)});
            return false;
        };
        defer allocator.free(availableLayer);
        _ = vk.vkEnumerateInstanceLayerProperties(&layerCount, &availableLayer[0]);

        var layersmatched: u32 = 0;
        var layerfound: bool = false;
        for (0..validationlayers.len) |i| {
            for (0..layerCount) |j| {
                if (std.mem.orderZ(u8, validationlayers[i], @ptrCast(&availableLayer[j].layerName)) == .eq) {
                    layersmatched = layersmatched + 1;
                    layerfound = true;
                }
            }
            if (!layerfound) {
                std.log.err("Unable to find validation layer: {s}", .{validationlayers[i]});
            }
        }
        std.log.info("{d}/{d} validation layers found", .{ layersmatched, validationlayers.len });

        return layersmatched == validationlayers.len;
    }
    fn checkextensions(
        allocator: std.mem.Allocator,
        reqextensioncount: u32,
        reqextensions: [*c]const [*c]const u8,
    ) void {
        var vkextensioncount: u32 = 0;
        _ = vk.vkEnumerateInstanceExtensionProperties(null, &vkextensioncount, null);

        var vkextensions = allocator.alloc(vk.VkExtensionProperties, vkextensioncount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan check extension array {s}", .{@errorName(err)});
            return;
        };
        defer allocator.free(vkextensions);
        _ = vk.vkEnumerateInstanceExtensionProperties(null, &vkextensioncount, &vkextensions[0]);

        if (reqextensions == null) {
            std.log.err("unable to retrive extensions", .{});
        }

        var extensions: u32 = reqextensioncount;
        var found: bool = false;
        for (0..reqextensioncount) |i| {
            found = false;
            for (0..vkextensioncount) |j| {
                if (std.mem.orderZ(u8, reqextensions[i], @ptrCast(&vkextensions[j].extensionName)) == .eq) {
                    found = true;
                }
            }
            if (!found) {
                extensions = extensions - 1;
                std.log.err("missing extension: {s}", .{reqextensions[i]});
            }
        }

        std.log.info("{d}/{d} extensions found", .{ extensions, reqextensioncount });
    }
};
const swapchainsupport = struct {
    allocator: std.mem.Allocator,
    capabilities: vk.VkSurfaceCapabilitiesKHR,
    formatcount: u32,
    formats: []vk.VkSurfaceFormatKHR,
    presentmodecount: u32,
    presentmode: []vk.VkPresentModeKHR,
    graphicalcontextself: *graphicalcontext,
    pub fn getSwapchainDetails(graphicalcontextself: *graphicalcontext, device: vk.VkPhysicalDevice) !*swapchainsupport {
        var self: *swapchainsupport = try graphicalcontextself.allocator.create(swapchainsupport);
        self.allocator = graphicalcontextself.allocator;
        self.graphicalcontextself = graphicalcontextself;
        _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, graphicalcontextself.surface, &self.capabilities);
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, graphicalcontextself.surface, &self.formatcount, null);
        self.formats = try graphicalcontextself.allocator.alloc(vk.VkSurfaceFormatKHR, @max(self.formatcount, 1));
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, graphicalcontextself.surface, &self.formatcount, &self.formats[0]);
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, graphicalcontextself.surface, &self.presentmodecount, null);
        self.presentmode = try graphicalcontextself.allocator.alloc(vk.VkPresentModeKHR, @max(self.presentmodecount, 1));
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, graphicalcontextself.surface, &self.presentmodecount, &self.presentmode[0]);
        return self;
    }
    pub fn deinit(self: *swapchainsupport) void {
        self.allocator.free(self.formats);
        self.allocator.free(self.presentmode);
        self.allocator.destroy(self);
    }
    pub fn chooseformat(self: *swapchainsupport) !vk.VkSurfaceFormatKHR {
        for (0..self.formatcount) |i| {
            if (self.formats[i].colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR and self.formats[i].format == vk.VK_FORMAT_B8G8R8A8_SRGB) {
                return self.formats[i];
            }
        }
        return error.UnableTOFindFormats;
    }
    pub fn choosepresentmode(self: *swapchainsupport) vk.VkPresentModeKHR {
        for (0..self.presentmodecount) |i| {
            if (self.presentmode[i] == vk.VK_PRESENT_MODE_MAILBOX_KHR) {
                return self.presentmode[i];
            }
        }
        return vk.VK_PRESENT_MODE_FIFO_KHR;
    }
    pub fn chooseswapextent(self: *swapchainsupport) vk.VkExtent2D {
        if (self.capabilities.currentExtent.width != std.math.maxInt(u32)) {
            return self.capabilities.currentExtent;
        }
        var glfwsize: [2]c_int = undefined;
        vk.glfwGetFramebufferSize(self.graphicalcontextself.window, &glfwsize[0], &glfwsize[1]);
        var actualextent: vk.VkExtent2D = .{ .width = @intCast(glfwsize[0]), .height = @intCast(glfwsize[1]) };
        actualextent.width = std.math.clamp(actualextent.width, self.capabilities.minImageExtent.width, self.capabilities.maxImageExtent.width);
        actualextent.height = std.math.clamp(actualextent.height, self.capabilities.minImageExtent.height, self.capabilities.maxImageExtent.height);
        return actualextent;
    }
};
const queuestr = struct {
    queue: vk.VkQueue,
    familyindex: u32,
};
const graphicsqueue = struct {
    allocator: std.mem.Allocator,
    availablequeues: u32,
    queues: []vk.VkQueueFamilyProperties,
    queuesfound: u32,
    searchresult: []u32,
    inUseQueue: []bool,
    pub fn getqueuefamily(graphicalcontextself: *graphicalcontext, device: vk.VkPhysicalDevice) !*graphicsqueue {
        var self: *graphicsqueue = try graphicalcontextself.allocator.create(graphicsqueue);
        self.allocator = graphicalcontextself.allocator;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &self.availablequeues, null);
        self.queues = try graphicalcontextself.allocator.alloc(vk.VkQueueFamilyProperties, self.availablequeues);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &self.availablequeues, self.queues.ptr);
        self.searchresult = try graphicalcontextself.allocator.alloc(u32, self.availablequeues);
        self.inUseQueue = try graphicalcontextself.allocator.alloc(bool, self.availablequeues);
        return self;
    }
    pub fn deinit(self: *graphicsqueue) void {
        self.allocator.free(self.inUseQueue);
        self.allocator.free(self.searchresult);
        self.allocator.free(self.queues);
        self.allocator.destroy(self);
    }
    pub fn queueflagsmatch(self: *graphicsqueue, queueFlags: u32) void {
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            if ((self.queues[i].queueFlags & queueFlags) == queueFlags) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn queueflagsmatchexact(self: *graphicsqueue, queueFlags: u32) void {
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            if (self.queues[i].queueFlags == queueFlags) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn checkpresentCapable(self: *graphicsqueue, graphicalcontextself: *graphicalcontext, physicaldevice: vk.VkPhysicalDevice) void {
        var presentsupport: vk.VkBool32 = vk.VK_FALSE;
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(
                physicaldevice,
                @intCast(i),
                graphicalcontextself.surface,
                &presentsupport,
            );
            if (presentsupport == vk.VK_TRUE) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn checkifinuse(self: *graphicsqueue, Queue: u32) bool {
        return self.inUseQueue[Queue];
    }
    pub fn markQueueInuse(self: *graphicsqueue, Queue: u32) void {
        self.inUseQueue[Queue] = true;
    }
    pub fn unmarkQueueInuse(self: *graphicsqueue, Queue: u32) void {
        self.inUseQueue[Queue] = false;
    }
};

const vertexbufferconfig = struct {
    pub fn getbindingdescription(T: type) vk.VkVertexInputBindingDescription {
        var bindingdescription: vk.VkVertexInputBindingDescription = .{};
        bindingdescription.binding = 0;
        bindingdescription.stride = @sizeOf(T);
        bindingdescription.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
        return bindingdescription;
    }
    pub fn getattributedescruptions(T: type) [3]vk.VkVertexInputAttributeDescription {
        var attributedescriptions: [3]vk.VkVertexInputAttributeDescription = undefined;
        attributedescriptions[0].binding = 0;
        attributedescriptions[0].location = 0;
        attributedescriptions[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[0].offset = @offsetOf(T, "vertex");

        attributedescriptions[1].binding = 0;
        attributedescriptions[1].location = 1;
        attributedescriptions[1].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[1].offset = @offsetOf(T, "color");

        attributedescriptions[2].binding = 0;
        attributedescriptions[2].location = 2;
        attributedescriptions[2].format = vk.VK_FORMAT_R32G32_SFLOAT;
        attributedescriptions[2].offset = @offsetOf(T, "texcoord");

        return attributedescriptions;
    }
};
export fn debugCallback(
    messageSeverity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageType: vk.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: [*c]const vk.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.c) vk.VkBool32 {
    _ = pUserData;
    const messagetype = switch (messageType) {
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "General",
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "Performance",
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT => "Device Adress binding",
        else => "Unknown",
    };
    if (validationlayerverbose and (messageSeverity == vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT)) {
        std.log.info("validation layer: {s} : {s}", .{ messagetype, pCallbackData.*.pMessage });
    } else if (messageSeverity == vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT) {
        std.log.info("validation layer: {s} : {s}", .{ messagetype, pCallbackData.*.pMessage });
    } else if (messageSeverity == vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
        std.log.warn("validation layer: {s} : {s}", .{ messagetype, pCallbackData.*.pMessage });
    } else if (messageSeverity == vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
        std.log.err("validation layer: {s} : {s}", .{ messagetype, pCallbackData.*.pMessage });
    }
    return vk.VK_FALSE;
}

const png = @cImport({
    @cInclude("png.h");
});
const c = @cImport({
    @cInclude("setjmp.h");
});
const drawing = @import("drawing.zig");
pub const vk = graphics.vk;
const graphics = @import("graphics.zig");
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
