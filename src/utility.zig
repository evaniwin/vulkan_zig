var validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
var validationlayerInstanceExtensions: [1][*c]const u8 = .{"VK_EXT_debug_utils"};
var deviceextensions: [1][*c]const u8 = .{"VK_KHR_swapchain"};
const enablevalidationlayers: bool = true;
const validationlayerverbose: bool = false;

pub const graphicalcontext = struct {
    allocator: std.mem.Allocator,
    window: *vk.GLFWwindow,
    instance: *vkinstance.Instance,
    physicaldevice: *vkinstance.PhysicalDevice,
    physicaldevicefeatures: vk.VkPhysicalDeviceFeatures,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    queuelist: *vklogicaldevice.graphicsqueue,
    surface: vk.VkSurfaceKHR,

    swapchain: *vkswapchain.swapchain,
    swapchainimageviews: *vkimage.imageviews,
    renderpass: vk.VkRenderPass,

    descriptorsetlayout: vk.VkDescriptorSetLayout,
    pipelinelayout: vk.VkPipelineLayout,
    graphicspipeline: vk.VkPipeline,
    swapchainframebuffers: []vk.VkFramebuffer,
    commandpool: *vkcommandbuffer.commandpool,
    commandpoolonetimecommand: *vkcommandbuffer.commandpool,
    descriptorpool: vk.VkDescriptorPool,
    descriptorsets: []vk.VkDescriptorSet,

    vertexbuffer: vk.VkBuffer,
    vertexbuffermemory: vk.VkDeviceMemory,
    indexbuffer: vk.VkBuffer,
    indexbuffermemory: vk.VkDeviceMemory,
    uniformbuffer: []vk.VkBuffer,
    uniformbuffermemory: []vk.VkDeviceMemory,
    uniformbuffermemotymapped: []?*anyopaque,
    miplevels: u32,
    textureimage: vk.VkImage,
    textureimagememory: vk.VkDeviceMemory,
    textureimageview: vk.VkImageView,
    textureimagesampler: vk.VkSampler,
    depthimage: vk.VkImage,
    depthimagememory: vk.VkDeviceMemory,
    depthimageview: vk.VkImageView,
    colorimage: vk.VkImage,
    colorimagememory: vk.VkDeviceMemory,
    colorimageview: vk.VkImageView,

    imageavailablesephamores: []vk.VkSemaphore,
    renderfinishedsephamores: []vk.VkSemaphore,
    inflightfences: []vk.VkFence,
    temperorycommandbufferinuse: vk.VkFence,
    vertices: []drawing.data,
    indices: []u32,
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
        const instanceparams: vkinstance.instancecreateinfo = .{
            .allocator = self.allocator,
            .InstanceExtensions = &[0][*c]const u8{},
            .validationlayers = &validationlayers,
            .validationlayerInstanceExtensions = &validationlayerInstanceExtensions,
            .enablevalidationlayers = true,
        };
        self.instance = try vkinstance.Instance.createinstance(instanceparams);
        //create surface associated with glfw window
        try createsurface(self.instance.instance, self.window, &self.surface);
        //get physical device with given params
        const physicaldeviceparams: vkinstance.pickphysicaldeviceinfo = .{
            .allocator = self.allocator,
            .instance = self.instance,
            .surface = self.surface,
            .deviceextensions = &deviceextensions,
        };
        self.physicaldevice = try vkinstance.PhysicalDevice.getphysicaldevice(physicaldeviceparams);
        self.queuelist = try vklogicaldevice.graphicsqueue.getqueuefamily(self.allocator, self.physicaldevice.physicaldevice);
        const logicaldeviceparams: vklogicaldevice.logicaldeviccecreateinfo = .{
            .allocator = self.allocator,
            .deviceextensions = &deviceextensions,
            .queuelist = self.queuelist,
            .surface = self.surface,
            .physicaldevice = self.physicaldevice,
            .enablevalidationlayers = true,
            .validationlayers = &validationlayers,
        };
        self.logicaldevice = try vklogicaldevice.LogicalDevice.createlogicaldevice(logicaldeviceparams);
        //load an obj model
        try loadmodel(self);

        const swapchaincreateparams: vkswapchain.swapchaincreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .physicaldevice = self.physicaldevice.physicaldevice,
            .surface = self.surface,
            .oldswapchain = null,
            .window = self.window,
        };
        self.swapchain = try vkswapchain.swapchain.createswapchain(swapchaincreateparams);

        const imageviewparams: vkimage.imageviewcreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .imageformat = self.swapchain.imageformat,
            .aspectflags = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .images = self.swapchain.images,
        };
        self.swapchainimageviews = try vkimage.imageviews.createimageviews(imageviewparams);

        try createsyncobjects(self);
        try vkrenderpass.createrenderpass(
            self.logicaldevice,
            self.swapchain,
            self.physicaldevice,
            try self.finddepthformat(),
            &self.renderpass,
        );
        try vkpipeline.createdescriptorsetlayout(self.logicaldevice, &self.descriptorsetlayout);
        try vkpipeline.creategraphicspipeline(
            self.logicaldevice,
            self.renderpass,
            self.physicaldevice,
            self.descriptorsetlayout,
            &self.pipelinelayout,
            &self.graphicspipeline,
        );
        try createcommandpools(self);
        try createcolorresources(self);
        try createdepthresources(self);
        try createswapchainframebuffers(self);
        try createtextureimage(self);
        try createtextureimageview(self);
        try createtextureimagesampler(self);
        try createvertexbuffer(self);
        try createindexbuffer(self);
        try createuniformbuffers(self);
        try createdescriptorpool(self);
        try createdescriptorSets(self);
        try self.commandpool.createcommandbuffer(0, @intCast(self.swapchain.images.len), vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        destroysyncobjects(self);
        destroytextureimagesampler(self);
        destroytextureimageview(self);
        destroyimage(self, self.textureimage, self.textureimagememory);
        destroycommandpools(self);
        destroyswapchainframebuffers(self);
        destroydepthresources(self);
        destroycolorresources(self);
        vk.vkDestroyPipeline(self.logicaldevice.device, self.graphicspipeline, null);
        vk.vkDestroyPipelineLayout(self.logicaldevice.device, self.pipelinelayout, null);
        vk.vkDestroyRenderPass(self.logicaldevice.device, self.renderpass, null);
        self.swapchainimageviews.destroyimageviews();

        self.swapchain.freeswapchain();

        freemodeldata(self);
        destroyuniformbuffers(self);
        destroydescriptorpool(self);
        destroydescriptorSets(self);
        vkpipeline.destroydescriptorsetlayout(self.logicaldevice, self.descriptorsetlayout);
        destroyindexbuffer(self);
        destroyvertexbuffer(self);
        self.logicaldevice.destroylogicaldevice();
        vk.vkDestroySurfaceKHR(self.instance.instance, self.surface, null);
        self.physicaldevice.deinit();
        self.instance.destroyinstance();
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
        renderpassbegininfo.renderArea.extent = self.swapchain.extent;
        var clearcolor: [3]vk.VkClearValue = undefined;
        clearcolor[0].color = vk.VkClearColorValue{ .int32 = .{ 0, 0, 0, 0 } };
        clearcolor[1].depthStencil = vk.VkClearDepthStencilValue{ .depth = 1, .stencil = 0 };
        clearcolor[2].color = vk.VkClearColorValue{ .int32 = .{ 0, 0, 0, 0 } };
        renderpassbegininfo.clearValueCount = clearcolor.len;
        renderpassbegininfo.pClearValues = &clearcolor[0];

        vk.vkCmdBeginRenderPass(commandbuffer, &renderpassbegininfo, vk.VK_SUBPASS_CONTENTS_INLINE);

        vk.vkCmdBindPipeline(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicspipeline);

        var viewport: vk.VkViewport = .{};
        viewport.x = 0;
        viewport.y = 0;
        viewport.height = @floatFromInt(self.swapchain.extent.height);
        viewport.width = @floatFromInt(self.swapchain.extent.width);
        viewport.minDepth = 0;
        viewport.maxDepth = 1;
        vk.vkCmdSetViewport(commandbuffer, 0, 1, &viewport);

        var scissor: vk.VkRect2D = .{};
        scissor.offset = .{ .x = 0, .y = 0 };
        scissor.extent = self.swapchain.extent;
        vk.vkCmdSetScissor(commandbuffer, 0, 1, &scissor);

        const vertexbuffers: [1]vk.VkBuffer = .{self.vertexbuffer};
        const offsets: [1]vk.VkDeviceSize = .{0};
        vk.vkCmdBindVertexBuffers(commandbuffer, 0, 1, &vertexbuffers[0], &offsets[0]);
        vk.vkCmdBindIndexBuffer(commandbuffer, self.indexbuffer, 0, vk.VK_INDEX_TYPE_UINT32);
        vk.vkCmdBindDescriptorSets(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipelinelayout, 0, 1, &self.descriptorsets[imageindex], 0, null);

        vk.vkCmdDrawIndexed(commandbuffer, @intCast(self.indices.len), 1, 0, 0, 0);

        vk.vkCmdEndRenderPass(commandbuffer);

        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbuffer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
    }

    pub fn recreateswapchains(self: *graphicalcontext) !void {
        const oldswapchain = self.swapchain;
        const swapchainimageslen = self.swapchain.images.len;
        const swapchaincreateparams: vkswapchain.swapchaincreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .physicaldevice = self.physicaldevice.physicaldevice,
            .surface = self.surface,
            .oldswapchain = oldswapchain.swapchain,
            .window = self.window,
        };
        const swapchain = try vkswapchain.swapchain.createswapchain(swapchaincreateparams);

        _ = vk.vkDeviceWaitIdle(self.logicaldevice.device);
        destroycolorresources(self);
        destroydepthresources(self);

        self.swapchainimageviews.destroyimageviews();
        vk.vkDestroyRenderPass(self.logicaldevice.device, self.renderpass, null);
        destroyswapchainframebuffers(self);
        self.swapchain.freeswapchain();
        self.swapchain = swapchain;

        const imageviewparams: vkimage.imageviewcreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .imageformat = self.swapchain.imageformat,
            .aspectflags = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .images = self.swapchain.images,
        };
        self.swapchainimageviews = try vkimage.imageviews.createimageviews(imageviewparams);
        try createcolorresources(self);
        try createdepthresources(self);
        try vkrenderpass.createrenderpass(
            self.logicaldevice,
            self.swapchain,
            self.physicaldevice,
            try self.finddepthformat(),
            &self.renderpass,
        );
        try createswapchainframebuffers(self);
        if (swapchainimageslen != self.swapchain.images.len) @panic("swap chain image length mismatch After Recreation");
    }
    fn createcolorresources(self: *graphicalcontext) !void {
        try self.createimage(
            self.logicaldevice.device,
            self.swapchain.extent.width,
            self.swapchain.extent.height,
            1,
            self.physicaldevice.MaxMsaaSamples,
            self.swapchain.imageformat,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT | vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.colorimage,
            &self.colorimagememory,
        );
        try vkimage.createimageview(
            self.logicaldevice,
            self.colorimage,
            &self.colorimageview,
            self.swapchain.imageformat,
            vk.VK_IMAGE_ASPECT_COLOR_BIT,
            1,
        );
    }
    fn destroycolorresources(self: *graphicalcontext) void {
        vk.vkDestroyImageView(self.logicaldevice.device, self.colorimageview, null);
        vk.vkDestroyImage(self.logicaldevice.device, self.colorimage, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.colorimagememory, null);
    }
    fn loadmodel(self: *graphicalcontext) !void {
        const object = try parseobj.obj.init(self.allocator, "/home/evaniwin/Work/vulkan_zig/resources/teapot.obj");
        defer object.deinit();
        try object.processformatdata();
        self.vertices = object.vdata;
        self.indices = object.idata;
    }
    fn freemodeldata(self: *graphicalcontext) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
    fn destroydepthresources(self: *graphicalcontext) void {
        vk.vkDestroyImageView(self.logicaldevice.device, self.depthimageview, null);
        vk.vkDestroyImage(self.logicaldevice.device, self.depthimage, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.depthimagememory, null);
    }
    fn createdepthresources(self: *graphicalcontext) !void {
        const depthformat: vk.VkFormat = try self.finddepthformat();
        try createimage(
            self,
            self.logicaldevice.device,
            self.swapchain.extent.width,
            self.swapchain.extent.height,
            1,
            self.physicaldevice.MaxMsaaSamples,
            depthformat,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.depthimage,
            &self.depthimagememory,
        );
        try vkimage.createimageview(
            self.logicaldevice,
            self.depthimage,
            &self.depthimageview,
            depthformat,
            vk.VK_IMAGE_ASPECT_DEPTH_BIT,
            1,
        );
        try transitionimagelayout(
            self,
            self.depthimage,
            depthformat,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            1,
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
            vk.vkGetPhysicalDeviceFormatProperties(self.physicaldevice.physicaldevice, format, &properties);
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
        samplercreateinfo.anisotropyEnable = self.physicaldevice.physicaldevicefeatures.samplerAnisotropy;
        samplercreateinfo.maxAnisotropy = self.physicaldevice.physicaldeviceproperties.limits.maxSamplerAnisotropy;
        samplercreateinfo.borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK;
        samplercreateinfo.unnormalizedCoordinates = vk.VK_FALSE;
        samplercreateinfo.compareEnable = vk.VK_FALSE;
        samplercreateinfo.compareOp = vk.VK_COMPARE_OP_ALWAYS;
        samplercreateinfo.mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR;
        samplercreateinfo.mipLodBias = 0;
        samplercreateinfo.minLod = 0;
        samplercreateinfo.maxLod = @floatFromInt(self.miplevels);

        if (vk.vkCreateSampler(self.logicaldevice.device, &samplercreateinfo, null, &self.textureimagesampler) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Image sampler for Texture", .{});
            return error.FailedToCreateTextureImageSampler;
        }
    }
    fn destroytextureimagesampler(self: *graphicalcontext) void {
        vk.vkDestroySampler(self.logicaldevice.device, self.textureimagesampler, null);
    }
    fn createtextureimageview(self: *graphicalcontext) !void {
        try vkimage.createimageview(
            self.logicaldevice,
            self.textureimage,
            &self.textureimageview,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_ASPECT_COLOR_BIT,
            self.miplevels,
        );
    }
    fn destroytextureimageview(self: *graphicalcontext) void {
        vkimage.destroyimageview(self.logicaldevice, self.textureimageview);
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
        const dir = std.c.fopen("/home/evaniwin/Work/vulkan_zig/resources/teapot.png", "rb");
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

        self.miplevels = @intFromFloat(std.math.floor(std.math.log2(@as(f32, @floatFromInt(@max(width, height))))));

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
        _ = vk.vkMapMemory(self.logicaldevice.device, stagingbuffermemory, 0, imagesize, 0, &memdata);
        const ptr: [*]u8 = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(u8, ptr[0..pixels.len], pixels);
        _ = vk.vkUnmapMemory(self.logicaldevice.device, stagingbuffermemory);

        try createimage(
            self,
            self.logicaldevice.device,
            width,
            height,
            self.miplevels,
            vk.VK_SAMPLE_COUNT_1_BIT,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vk.VK_IMAGE_USAGE_SAMPLED_BIT | vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.textureimage,
            &self.textureimagememory,
        );
        try self.transitionimagelayout(
            self.textureimage,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            self.miplevels,
        );
        try self.copybuffertoimage(
            stagingbuffer,
            self.textureimage,
            width,
            height,
        );

        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
        try self.generatemipmaps(
            self.textureimage,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            width,
            height,
            self.miplevels,
        );
    }
    fn destroyimage(self: *graphicalcontext, image: vk.VkImage, imagememory: vk.VkDeviceMemory) void {
        vk.vkDestroyImage(self.logicaldevice.device, image, null);
        vk.vkFreeMemory(self.logicaldevice.device, imagememory, null);
    }
    fn generatemipmaps(self: *graphicalcontext, image: vk.VkImage, imageformat: vk.VkFormat, imgwidth: u32, imgheight: u32, miplevels: u32) !void {
        var formatproperties: vk.VkFormatProperties = .{};
        vk.vkGetPhysicalDeviceFormatProperties(self.physicaldevice.physicaldevice, imageformat, &formatproperties);
        if ((formatproperties.optimalTilingFeatures & vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) == 0) {
            std.log.err("Minmap generation failed: Device does not suppert linear blitting", .{});
            return error.MinmapGenerationFailed;
        }
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands(0);
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
        try self.endsingletimecommands(commandbuffer, 0);
    }
    fn createimage(
        self: *graphicalcontext,
        device: vk.VkDevice,
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
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands(0);

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
        try self.endsingletimecommands(commandbuffer, 0);
    }
    fn transitionimagelayout(self: *graphicalcontext, image: vk.VkImage, format: vk.VkFormat, oldlayout: vk.VkImageLayout, newlayout: vk.VkImageLayout, miplevels: u32) !void {
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands(0);
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

        try self.endsingletimecommands(commandbuffer, 0);
    }
    fn createdescriptorpool(self: *graphicalcontext) !void {
        var descriptorpoolsizes: [2]vk.VkDescriptorPoolSize = undefined;
        descriptorpoolsizes[0].type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        descriptorpoolsizes[0].descriptorCount = @intCast(self.swapchain.images.len);
        descriptorpoolsizes[1].type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        descriptorpoolsizes[1].descriptorCount = @intCast(self.swapchain.images.len);

        var poolcreateinfo: vk.VkDescriptorPoolCreateInfo = .{};
        poolcreateinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        poolcreateinfo.poolSizeCount = @intCast(descriptorpoolsizes.len);
        poolcreateinfo.pPoolSizes = &descriptorpoolsizes[0];
        poolcreateinfo.maxSets = @intCast(self.swapchain.images.len);

        if (vk.vkCreateDescriptorPool(self.logicaldevice.device, &poolcreateinfo, null, &self.descriptorpool) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Pool", .{});
            return error.FailedToCreateDescriptorPool;
        }
    }
    fn destroydescriptorpool(self: *graphicalcontext) void {
        vk.vkDestroyDescriptorPool(self.logicaldevice.device, self.descriptorpool, null);
    }
    fn createdescriptorSets(self: *graphicalcontext) !void {
        var descriptorsetlayouts: []vk.VkDescriptorSetLayout = try self.allocator.alloc(vk.VkDescriptorSetLayout, self.swapchain.images.len);
        defer self.allocator.free(descriptorsetlayouts);
        for (0..self.swapchain.images.len) |i| {
            descriptorsetlayouts[i] = self.descriptorsetlayout;
        }
        self.descriptorsets = try self.allocator.alloc(vk.VkDescriptorSet, self.swapchain.images.len);

        var descriptorsetallocinfo: vk.VkDescriptorSetAllocateInfo = .{};
        descriptorsetallocinfo.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        descriptorsetallocinfo.descriptorPool = self.descriptorpool;
        descriptorsetallocinfo.descriptorSetCount = @intCast(self.swapchain.images.len);
        descriptorsetallocinfo.pSetLayouts = &descriptorsetlayouts[0];

        if (vk.vkAllocateDescriptorSets(self.logicaldevice.device, &descriptorsetallocinfo, &self.descriptorsets[0]) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Descriptor Sets", .{});
            return error.FailedToCreateDescriptorSets;
        }
        for (0..self.swapchain.images.len) |i| {
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

            vk.vkUpdateDescriptorSets(self.logicaldevice.device, writedescriptorset.len, &writedescriptorset[0], 0, null);
        }
    }
    fn destroydescriptorSets(self: *graphicalcontext) void {
        self.allocator.free(self.descriptorsets);
    }
    fn createuniformbuffers(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.uniformbufferobject);
        const count = self.swapchain.images.len;
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
            _ = vk.vkMapMemory(self.logicaldevice.device, self.uniformbuffermemory[i], 0, buffersize, 0, &self.uniformbuffermemotymapped[i]);
        }
    }
    fn destroyuniformbuffers(self: *graphicalcontext) void {
        for (0..self.uniformbuffer.len) |i| {
            vk.vkDestroyBuffer(self.logicaldevice.device, self.uniformbuffer[i], null);
            vk.vkFreeMemory(self.logicaldevice.device, self.uniformbuffermemory[i], null);
        }
        self.allocator.free(self.uniformbuffer);
        self.allocator.free(self.uniformbuffermemory);
        self.allocator.free(self.uniformbuffermemotymapped);
    }
    fn createindexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(u32) * self.indices.len;
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
        _ = vk.vkMapMemory(self.logicaldevice.device, stagingbuffermemory, 0, buffersize, 0, &memdata);
        const ptr: [*]u32 = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(u32, ptr[0..self.indices.len], self.indices);
        _ = vk.vkUnmapMemory(self.logicaldevice.device, stagingbuffermemory);

        try createbuffer(
            self,
            buffersize,
            vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.indexbuffer,
            &self.indexbuffermemory,
        );
        try copybuffer(self, stagingbuffer, self.indexbuffer, buffersize);
        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
    }
    fn destroyindexbuffer(self: *graphicalcontext) void {
        vk.vkDestroyBuffer(self.logicaldevice.device, self.indexbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.indexbuffermemory, null);
    }
    fn beginsingletimecommands(self: *graphicalcontext, index: u32) !vk.VkCommandBuffer {
        _ = vk.vkWaitForFences(
            self.logicaldevice.device,
            1,
            &self.temperorycommandbufferinuse,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        _ = vk.vkResetFences(self.logicaldevice.device, 1, &self.temperorycommandbufferinuse);

        try self.commandpoolonetimecommand.createcommandbuffer(index, 1, vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
        var begininfo: vk.VkCommandBufferBeginInfo = .{};
        begininfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        begininfo.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

        if (vk.vkBeginCommandBuffer(self.commandpoolonetimecommand.commandbuffers[index][0], &begininfo) != vk.VK_SUCCESS) {
            std.log.err("Unable to Begin Recording Commandbufffer datatransfer", .{});
            return error.FailedToBeginRecordingCommandBuffer;
        }
        return self.commandpoolonetimecommand.commandbuffers[index][0];
    }
    fn endsingletimecommands(self: *graphicalcontext, commandbuffer: vk.VkCommandBuffer, index: u32) !void {
        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbufffer datatransfer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
        var submitinfo: vk.VkSubmitInfo = .{};
        submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitinfo.commandBufferCount = 1;
        submitinfo.pCommandBuffers = &commandbuffer;

        if (vk.vkQueueSubmit(self.logicaldevice.graphicsqueue.queue, 1, &submitinfo, self.temperorycommandbufferinuse) != vk.VK_SUCCESS) {
            std.log.err("Unable to Submit Queue", .{});
            return error.QueueSubmissionFailed;
        }
        _ = vk.vkWaitForFences(
            self.logicaldevice.device,
            1,
            &self.temperorycommandbufferinuse,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        self.commandpoolonetimecommand.freecommandbuffer(index);
    }
    fn copybuffer(self: *graphicalcontext, srcbuffer: vk.VkBuffer, dstbuffer: vk.VkBuffer, size: vk.VkDeviceSize) !void {
        const commandbuffer: vk.VkCommandBuffer = try self.beginsingletimecommands(0);
        var copyregion: vk.VkBufferCopy = .{};
        copyregion.srcOffset = 0;
        copyregion.dstOffset = 0;
        copyregion.size = size;
        vk.vkCmdCopyBuffer(commandbuffer, srcbuffer, dstbuffer, 1, &copyregion);
        try self.endsingletimecommands(commandbuffer, 0);
    }
    fn createvertexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.data) * self.vertices.len;
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
        _ = vk.vkMapMemory(self.logicaldevice.device, stagingbuffermemory, 0, buffersize, 0, &memdata);
        const ptr: [*]drawing.data = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(drawing.data, ptr[0..self.vertices.len], self.vertices);
        _ = vk.vkUnmapMemory(self.logicaldevice.device, stagingbuffermemory);

        try createbuffer(
            self,
            buffersize,
            vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.vertexbuffer,
            &self.vertexbuffermemory,
        );
        try copybuffer(self, stagingbuffer, self.vertexbuffer, buffersize);
        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
    }
    fn destroyvertexbuffer(self: *graphicalcontext) void {
        vk.vkDestroyBuffer(self.logicaldevice.device, self.vertexbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.vertexbuffermemory, null);
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
        if (vk.vkCreateBuffer(self.logicaldevice.device, &buffercreateinfo, null, buffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to create vertex buffer", .{});
            return error.FailedToCreateVertexBuffer;
        }

        var memoryrequirements: vk.VkMemoryRequirements = .{};
        vk.vkGetBufferMemoryRequirements(self.logicaldevice.device, buffer.*, &memoryrequirements);

        var allocationinfo: vk.VkMemoryAllocateInfo = .{};
        allocationinfo.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocationinfo.allocationSize = memoryrequirements.size;
        allocationinfo.memoryTypeIndex = try findmemorytype(
            self,
            memoryrequirements.memoryTypeBits,
            memorypropertiesflags,
        );
        if (vk.vkAllocateMemory(self.logicaldevice.device, &allocationinfo, null, buffermemory) != vk.VK_SUCCESS) {
            std.log.err("Unable to Allocate Gpu Memory", .{});
            return error.FailedToAllocateGpuMemory;
        }
        _ = vk.vkBindBufferMemory(self.logicaldevice.device, buffer.*, buffermemory.*, 0);
    }
    fn findmemorytype(self: *graphicalcontext, typefilter: u32, properties: vk.VkMemoryPropertyFlags) !u32 {
        var memoryproperties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physicaldevice.physicaldevice, &memoryproperties);
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
        for (0..self.swapchain.images.len) |i| {
            vk.vkDestroySemaphore(self.logicaldevice.device, self.imageavailablesephamores[i], null);
            vk.vkDestroySemaphore(self.logicaldevice.device, self.renderfinishedsephamores[i], null);
            vk.vkDestroyFence(self.logicaldevice.device, self.inflightfences[i], null);
        }
        vk.vkDestroyFence(self.logicaldevice.device, self.temperorycommandbufferinuse, null);
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
        self.imageavailablesephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain.images.len);
        self.renderfinishedsephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain.images.len);
        self.inflightfences = try self.allocator.alloc(vk.VkFence, self.swapchain.images.len);
        for (0..self.swapchain.images.len) |i| {
            if (vk.vkCreateSemaphore(self.logicaldevice.device, &sephamorecreateinfo, null, &self.imageavailablesephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
            if (vk.vkCreateSemaphore(self.logicaldevice.device, &sephamorecreateinfo, null, &self.renderfinishedsephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
            if (vk.vkCreateFence(self.logicaldevice.device, &fencecreateinfo, null, &self.inflightfences[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Cpu fence (render)", .{});
                return error.UnableToCreateFence;
            }
        }
        if (vk.vkCreateFence(self.logicaldevice.device, &fencecreateinfo, null, &self.temperorycommandbufferinuse) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Cpu fence (datatransfer)", .{});
            return error.UnableToCreateFence;
        }
    }

    fn createcommandpools(self: *graphicalcontext) !void {
        var commandpoolcreateparams: vkcommandbuffer.commandpoolcreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .queueFamilyIndex = self.logicaldevice.graphicsqueue.familyindex,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .commandbuffers = 2,
        };
        self.commandpool = try vkcommandbuffer.commandpool.init(commandpoolcreateparams);

        commandpoolcreateparams = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .queueFamilyIndex = self.logicaldevice.graphicsqueue.familyindex,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT | vk.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT,
            .commandbuffers = 2,
        };
        self.commandpoolonetimecommand = try vkcommandbuffer.commandpool.init(commandpoolcreateparams);
    }
    fn destroycommandpools(self: *graphicalcontext) void {
        self.commandpool.free();
        self.commandpoolonetimecommand.free();
    }
    fn destroyswapchainframebuffers(self: *graphicalcontext) void {
        for (0..self.swapchainframebuffers.len) |i| {
            vkimage.destroyframebuffer(self.logicaldevice, self.swapchainframebuffers[i]);
        }
        self.allocator.free(self.swapchainframebuffers);
    }
    fn createswapchainframebuffers(self: *graphicalcontext) !void {
        self.swapchainframebuffers = try self.allocator.alloc(vk.VkFramebuffer, self.swapchainimageviews.imageviews.len);

        for (0..self.swapchainimageviews.imageviews.len) |i| {
            var attachments: [3]vk.VkImageView = .{ self.colorimageview, self.depthimageview, self.swapchainimageviews.imageviews[i] };
            try vkimage.createframebuffer(
                self.logicaldevice,
                &self.swapchainframebuffers[i],
                self.renderpass,
                &attachments,
                self.swapchain.extent,
            );
        }
    }
    fn createsurface(instance: vk.VkInstance, window: *vk.GLFWwindow, surface: *vk.VkSurfaceKHR) !void {
        if (vk.glfwCreateWindowSurface(instance, window, null, surface) != vk.VK_SUCCESS) {
            std.log.err("Glfw surface creation failed", .{});
            return error.GlfwSurfaceCreationFailed;
        }
    }
};
const png = @cImport({
    @cInclude("png.h");
});
const c = @cImport({
    @cInclude("setjmp.h");
});
const parseobj = @import("parseobj.zig");
const drawing = @import("drawing.zig");
pub const vk = graphics.vk;
const graphics = @import("graphics.zig");
const vkinstance = @import("vulkan/instance.zig");
const vkswapchain = @import("vulkan/swapchain.zig");
const vklogicaldevice = @import("vulkan/logicaldevice.zig");
const vkimage = @import("vulkan/image.zig");
const vkrenderpass = @import("vulkan/renderpass.zig");
const vkpipeline = @import("vulkan/pipeline.zig");
const vkcommandbuffer = @import("vulkan/commandbuffer.zig");
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
