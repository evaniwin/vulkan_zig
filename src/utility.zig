var validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
var validationlayerInstanceExtensions: [1][*c]const u8 = .{"VK_EXT_debug_utils"};
var deviceextensions: [1][*c]const u8 = .{"VK_KHR_swapchain"};
const enablevalidationlayers: bool = true;
const validationlayerverbose: bool = false;
const particlecount = 256 * 1;
pub const MAX_FRAMES_IN_FLIGHT: u32 = 3;

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

    descriptorsetlayout_3d: vk.VkDescriptorSetLayout,
    pipelinelayout_3d: vk.VkPipelineLayout,
    graphicspipeline_3d: vk.VkPipeline,

    descriptorsetlayout_particle: vk.VkDescriptorSetLayout,
    pipelinelayout_particle: vk.VkPipelineLayout,
    graphicspipeline_particle: vk.VkPipeline,
    computepipelinelayout: vk.VkPipelineLayout,
    computepipeline: vk.VkPipeline,

    commandpool: *vkcommandbuffer.commandpool,
    commandpoolonetimecommand: *vkcommandbuffer.commandpool,
    descriptorpool_3d: *vkdescriptor.descriptorpool,
    descriptorpool_particle: *vkdescriptor.descriptorpool,

    vertexbuffer: vk.VkBuffer,
    vertexbuffermemory: vk.VkDeviceMemory,
    indexbuffer: vk.VkBuffer,
    indexbuffermemory: vk.VkDeviceMemory,
    uniformbuffer_compute: []vk.VkBuffer,
    uniformbuffermemory_compute: []vk.VkDeviceMemory,
    uniformbuffermemotymapped_compute: []?*anyopaque,
    uniformbuffer_3d: []vk.VkBuffer,
    uniformbuffermemory_3d: []vk.VkDeviceMemory,
    uniformbuffermemotymapped_3d: []?*anyopaque,
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
    shaderstoragebuffers: []vk.VkBuffer,
    shaderstoragebuffersmemory: []vk.VkDeviceMemory,

    imageavailablesephamores: []vk.VkSemaphore,
    renderfinishedsephamores: []vk.VkSemaphore,
    inflightfences: []vk.VkFence,
    computefinishedsephamores: []vk.VkSemaphore,
    computeinflightfences: []vk.VkFence,
    computepreviousfinishedsephamores: []vk.VkSemaphore,
    graphicspreviousfinishedsephamores: []vk.VkSemaphore,
    model: parseobj.model,
    lastframetime: f32 = 0.00005,
    lasttime: f64,
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
            .enablevalidationlayers = enablevalidationlayers,
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
        try resourceloading.loadmodel(self.allocator, &self.model, "/home/evaniwin/Work/vulkan_zig/resources/teapot.obj");

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

        try vkdescriptor.creategraphicsdescriptorsetlayout(self.logicaldevice, &self.descriptorsetlayout_3d);
        const depthformat = try self.finddepthformat();
        try vkpipeline.creategraphicspipeline(
            self.logicaldevice,
            self.physicaldevice,
            self.descriptorsetlayout_3d,
            self.swapchain,
            depthformat,
            depthformat,
            &self.pipelinelayout_3d,
            &self.graphicspipeline_3d,
        );
        try createcommandpools(self);
        try createcolorresources(self);
        try createdepthresources(self);
        try createtextureimage(self);
        try createtextureimageview(self);
        try createtextureimagesampler(self);
        try createvertexbuffer(self);
        try createindexbuffer(self);
        try createuniformbuffers(self);
        const descriptorpoolcreateparams_3d: vkdescriptor.descriptorpoolcreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .descriptorsetlayout = self.descriptorsetlayout_3d,
            .descriptorcount = @intCast(self.swapchain.images.len),
        };
        self.descriptorpool_3d = try vkdescriptor.descriptorpool.init_createdescriptorpool_graphics(descriptorpoolcreateparams_3d);
        try self.descriptorpool_3d.createdescriptorSets_graphics(
            self.uniformbuffer_3d,
            self.textureimageview,
            self.textureimagesampler,
        );
        try vkdescriptor.createcomputedescriptorsetlayout(self.logicaldevice, &self.descriptorsetlayout_particle);
        try vkpipeline.creategraphicspipeline_compute(
            self.logicaldevice,
            self.swapchain,
            &self.pipelinelayout_particle,
            &self.graphicspipeline_particle,
        );
        try vkpipeline.createcomputepipeline(
            self.logicaldevice,
            self.descriptorsetlayout_particle,
            &self.computepipelinelayout,
            &self.computepipeline,
        );

        try createshaderstoragebuffer(self);
        try createuniformbuffers_compute(self);
        const descriptorpoolcreateparams_particle: vkdescriptor.descriptorpoolcreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .descriptorsetlayout = self.descriptorsetlayout_particle,
            .descriptorcount = MAX_FRAMES_IN_FLIGHT,
        };
        self.descriptorpool_particle = try vkdescriptor.descriptorpool.init_createdescriptorpool_compute(descriptorpoolcreateparams_particle);
        try self.descriptorpool_particle.createdescriptorSets_compute(
            self.uniformbuffer_compute,
            self.shaderstoragebuffers,
            particlecount,
        );

        try self.commandpool.createcommandbuffer(0, @intCast(self.swapchain.images.len), vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
        try self.commandpool.createcommandbuffer(1, @intCast(self.swapchain.images.len), vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
        try self.commandpool.createcommandbuffer(2, @intCast(self.swapchain.images.len), vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        destroysyncobjects(self);
        destroytextureimagesampler(self);
        destroytextureimageview(self);
        vkimage.destroyimage(self.logicaldevice, self.textureimage, self.textureimagememory);
        destroycommandpools(self);
        destroydepthresources(self);
        destroycolorresources(self);
        vk.vkDestroyPipeline(self.logicaldevice.device, self.graphicspipeline_particle, null);
        vk.vkDestroyPipelineLayout(self.logicaldevice.device, self.pipelinelayout_particle, null);
        vk.vkDestroyPipeline(self.logicaldevice.device, self.computepipeline, null);
        vk.vkDestroyPipelineLayout(self.logicaldevice.device, self.computepipelinelayout, null);
        vk.vkDestroyPipeline(self.logicaldevice.device, self.graphicspipeline_3d, null);
        vk.vkDestroyPipelineLayout(self.logicaldevice.device, self.pipelinelayout_3d, null);
        self.swapchainimageviews.destroyimageviews();

        self.swapchain.freeswapchain();

        self.model.freemodeldata();
        destroyuniformbuffers_compute(self);
        destroyuniformbuffers(self);
        destroyshaderstoragebuffer(self);
        self.descriptorpool_particle.destroydescriptorpool();
        self.descriptorpool_3d.destroydescriptorpool();
        vkdescriptor.destroydescriptorsetlayout(self.logicaldevice, self.descriptorsetlayout_3d);
        vkdescriptor.destroydescriptorsetlayout(self.logicaldevice, self.descriptorsetlayout_particle);
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

        var imagememorybarrier: vk.VkImageMemoryBarrier = .{};
        imagememorybarrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        imagememorybarrier.srcAccessMask = 0;
        imagememorybarrier.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        imagememorybarrier.oldLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        imagememorybarrier.newLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        imagememorybarrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.image = self.swapchain.images[imageindex];
        imagememorybarrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        imagememorybarrier.subresourceRange.baseMipLevel = 0;
        imagememorybarrier.subresourceRange.levelCount = 1;
        imagememorybarrier.subresourceRange.baseArrayLayer = 0;
        imagememorybarrier.subresourceRange.layerCount = 1;

        vk.vkCmdPipelineBarrier(
            commandbuffer,
            vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &imagememorybarrier,
        );

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

        var colorattachment: vk.VkRenderingAttachmentInfo = .{};
        colorattachment.sType = vk.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        colorattachment.pNext = null;
        colorattachment.imageView = self.colorimageview;
        colorattachment.imageLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        colorattachment.resolveMode = 0;
        colorattachment.resolveImageView = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        colorattachment.resolveImageView = self.swapchainimageviews.imageviews[imageindex];
        colorattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
        colorattachment.clearValue = .{ .color = vk.VkClearColorValue{ .int32 = .{ 0, 0, 0, 0 } } };

        var depthattachment: vk.VkRenderingAttachmentInfo = .{};
        depthattachment.sType = vk.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        depthattachment.pNext = null;
        depthattachment.imageView = self.depthimageview;
        depthattachment.imageLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
        depthattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        depthattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
        depthattachment.clearValue = .{ .depthStencil = vk.VkClearDepthStencilValue{ .depth = 1, .stencil = 0 } };

        var renderinginfo: vk.VkRenderingInfo = .{};
        renderinginfo.sType = vk.VK_STRUCTURE_TYPE_RENDERING_INFO;
        renderinginfo.renderArea.offset = .{ .x = 0, .y = 0 };
        renderinginfo.renderArea.extent = self.swapchain.extent;
        renderinginfo.layerCount = 1;
        renderinginfo.colorAttachmentCount = 1;
        renderinginfo.pColorAttachments = &colorattachment;
        renderinginfo.pDepthAttachment = &depthattachment;
        renderinginfo.pStencilAttachment = &depthattachment;
        vk.vkCmdBeginRendering(commandbuffer, &renderinginfo);

        vk.vkCmdBindPipeline(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicspipeline_3d);

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
        vk.vkCmdBindDescriptorSets(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipelinelayout_3d, 0, 1, &self.descriptorpool_3d.descriptorsets[imageindex], 0, null);

        vk.vkCmdDrawIndexed(commandbuffer, @intCast(self.model.indices.len), 1, 0, 0, 0);

        vk.vkCmdEndRendering(commandbuffer);

        imagememorybarrier = .{};
        imagememorybarrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        imagememorybarrier.srcAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        imagememorybarrier.dstAccessMask = 0;
        imagememorybarrier.oldLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        imagememorybarrier.newLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        imagememorybarrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.image = self.swapchain.images[imageindex];
        imagememorybarrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        imagememorybarrier.subresourceRange.baseMipLevel = 0;
        imagememorybarrier.subresourceRange.levelCount = 1;
        imagememorybarrier.subresourceRange.baseArrayLayer = 0;
        imagememorybarrier.subresourceRange.layerCount = 1;

        var barrierdepinfo: vk.VkDependencyInfo = {};
        barrierdepinfo.sType = vk.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
        barrierdepinfo.pNext = null;
        barrierdepinfo.dependencyFlags = 0;
        barrierdepinfo.imageMemoryBarrierCount = 1;
        barrierdepinfo.pImageMemoryBarriers = &imagememorybarrier;

        vk.vkCmdPipelineBarrier2(commandbuffer, &barrierdepinfo);
        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbuffer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
    }
    pub fn recordcommandbuffer_compute(self: *graphicalcontext, commandbuffer: vk.VkCommandBuffer, imageindex: u32, currentframe: u32) !void {
        var commandbufferbegininfo: vk.VkCommandBufferBeginInfo = .{};
        commandbufferbegininfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        commandbufferbegininfo.flags = 0;
        commandbufferbegininfo.pInheritanceInfo = null;
        if (vk.vkBeginCommandBuffer(commandbuffer, &commandbufferbegininfo) != vk.VK_SUCCESS) {
            std.log.err("Unable to Begin Recording Commandbufffer", .{});
            return error.FailedToBeginRecordingCommandBuffer;
        }

        var imagememorybarrier: vk.VkImageMemoryBarrier = .{};
        imagememorybarrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        imagememorybarrier.srcAccessMask = 0;
        imagememorybarrier.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        imagememorybarrier.oldLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        imagememorybarrier.newLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        imagememorybarrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.image = self.swapchain.images[imageindex];
        imagememorybarrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        imagememorybarrier.subresourceRange.baseMipLevel = 0;
        imagememorybarrier.subresourceRange.levelCount = 1;
        imagememorybarrier.subresourceRange.baseArrayLayer = 0;
        imagememorybarrier.subresourceRange.layerCount = 1;

        vk.vkCmdPipelineBarrier(
            commandbuffer,
            vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &imagememorybarrier,
        );

        var colorattachment: vk.VkRenderingAttachmentInfo = .{};
        colorattachment.sType = vk.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        colorattachment.pNext = null;
        colorattachment.imageView = self.swapchainimageviews.imageviews[imageindex];
        colorattachment.imageLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        colorattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        colorattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
        const clearcolor: vk.VkClearValue = .{ .color = vk.VkClearColorValue{ .int32 = .{ 0, 0, 0, 0 } } };
        colorattachment.clearValue = clearcolor;

        var renderinginfo: vk.VkRenderingInfo = .{};
        renderinginfo.sType = vk.VK_STRUCTURE_TYPE_RENDERING_INFO;
        renderinginfo.renderArea.offset = .{ .x = 0, .y = 0 };
        renderinginfo.renderArea.extent = self.swapchain.extent;
        renderinginfo.layerCount = 1;
        renderinginfo.colorAttachmentCount = 1;
        renderinginfo.pColorAttachments = &colorattachment;
        vk.vkCmdBeginRendering(commandbuffer, &renderinginfo);

        vk.vkCmdBindPipeline(commandbuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicspipeline_particle);

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

        const offsets: [1]vk.VkDeviceSize = .{0};
        vk.vkCmdBindVertexBuffers(commandbuffer, 0, 1, &self.shaderstoragebuffers[currentframe], &offsets[0]);

        vk.vkCmdDraw(
            commandbuffer,
            particlecount,
            1,
            0,
            0,
        );

        vk.vkCmdEndRendering(commandbuffer);
        imagememorybarrier = .{};
        imagememorybarrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        imagememorybarrier.srcAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        imagememorybarrier.dstAccessMask = 0;
        imagememorybarrier.oldLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        imagememorybarrier.newLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        imagememorybarrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        imagememorybarrier.image = self.swapchain.images[imageindex];
        imagememorybarrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        imagememorybarrier.subresourceRange.baseMipLevel = 0;
        imagememorybarrier.subresourceRange.levelCount = 1;
        imagememorybarrier.subresourceRange.baseArrayLayer = 0;
        imagememorybarrier.subresourceRange.layerCount = 1;

        vk.vkCmdPipelineBarrier(
            commandbuffer,
            vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &imagememorybarrier,
        );
        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbuffer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
    }
    pub fn recordcomputecommandbuffer(self: *graphicalcontext, commandbuffer: vk.VkCommandBuffer, imageindex: u32) !void {
        var commandbufferbegininfo: vk.VkCommandBufferBeginInfo = .{};
        commandbufferbegininfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        commandbufferbegininfo.flags = 0;
        commandbufferbegininfo.pInheritanceInfo = null;
        if (vk.vkBeginCommandBuffer(commandbuffer, &commandbufferbegininfo) != vk.VK_SUCCESS) {
            std.log.err("Unable to Begin Recording Commandbufffer", .{});
            return error.FailedToBeginRecordingCommandBuffer;
        }

        vk.vkCmdBindPipeline(
            commandbuffer,
            vk.VK_PIPELINE_BIND_POINT_COMPUTE,
            self.computepipeline,
        );
        var descriptorsets: [1]vk.VkDescriptorSet = .{self.descriptorpool_particle.descriptorsets[imageindex]};
        vk.vkCmdBindDescriptorSets(
            commandbuffer,
            vk.VK_PIPELINE_BIND_POINT_COMPUTE,
            self.computepipelinelayout,
            0,
            1,
            &descriptorsets[0],
            0,
            null,
        );

        vk.vkCmdDispatch(
            commandbuffer,
            particlecount / 256,
            1,
            1,
        );

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
        // destroycolorresources(self);
        // destroydepthresources(self);

        self.swapchainimageviews.destroyimageviews();
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
        //try createcolorresources(self);
        //try createdepthresources(self);
        if (swapchainimageslen != self.swapchain.images.len) @panic("swap chain image length mismatch After Recreation");
    }
    fn createshaderstoragebuffer(self: *graphicalcontext) !void {
        self.shaderstoragebuffers = try self.allocator.alloc(vk.VkBuffer, self.swapchain.images.len);
        self.shaderstoragebuffersmemory = try self.allocator.alloc(vk.VkDeviceMemory, self.swapchain.images.len);

        const points = try self.allocator.alloc(drawing.points, particlecount);
        defer self.allocator.free(points);
        var pgrm = std.Random.Xoroshiro128.init(0);
        const random = pgrm.random();
        for (0..particlecount) |index| {
            const theta = -2.0 * std.math.pi * (@as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(particlecount)));
            const cx = 0.5 * @as(f32, std.math.sin(theta)) + 0.1 * random.float(f32);
            const cy = 0.5 * @as(f32, std.math.cos(theta)) + 0.1 * random.float(f32);
            points[index] = .{
                .position = .{ cx, cy },
                .velocity = mathmatrix.vec2normalize(.{ cx, cy }),
                .color = .{ random.float(f32), random.float(f32), random.float(f32), 1 },
            };
        }

        const buffersize = @sizeOf(drawing.points) * points.len;
        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try vkbuffer.createbuffer(
            self.logicaldevice,
            self.physicaldevice,
            buffersize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );
        vkbuffer.copydatatobuffer(
            self.logicaldevice,
            stagingbuffermemory,
            buffersize,
            drawing.points,
            points,
        );
        for (0..self.swapchain.images.len) |i| {
            try vkbuffer.createbuffer(
                self.logicaldevice,
                self.physicaldevice,
                buffersize,
                vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                &self.shaderstoragebuffers[i],
                &self.shaderstoragebuffersmemory[i],
            );
            try vkbuffer.copybuffertobuffer(
                self.commandpoolonetimecommand,
                stagingbuffer,
                self.shaderstoragebuffers[i],
                buffersize,
            );
        }

        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
    }
    fn destroyshaderstoragebuffer(self: *graphicalcontext) void {
        for (0..self.shaderstoragebuffers.len) |i| {
            vk.vkDestroyBuffer(self.logicaldevice.device, self.shaderstoragebuffers[i], null);
            vk.vkFreeMemory(self.logicaldevice.device, self.shaderstoragebuffersmemory[i], null);
        }
        self.allocator.free(self.shaderstoragebuffers);
        self.allocator.free(self.shaderstoragebuffersmemory);
    }
    fn createcolorresources(self: *graphicalcontext) !void {
        try vkimage.createimage(
            self.physicaldevice,
            self.logicaldevice,
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
    fn destroydepthresources(self: *graphicalcontext) void {
        vk.vkDestroyImageView(self.logicaldevice.device, self.depthimageview, null);
        vk.vkDestroyImage(self.logicaldevice.device, self.depthimage, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.depthimagememory, null);
    }
    fn createdepthresources(self: *graphicalcontext) !void {
        const depthformat: vk.VkFormat = try self.finddepthformat();
        try vkimage.createimage(
            self.physicaldevice,
            self.logicaldevice,
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
        try vkimage.transitionimagelayout(
            self.commandpoolonetimecommand,
            self.depthimage,
            depthformat,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            1,
        );
    }

    fn finddepthformat(self: *graphicalcontext) !vk.VkFormat {
        var formats: [3]vk.VkFormat = .{ vk.VK_FORMAT_D32_SFLOAT_S8_UINT, vk.VK_FORMAT_D24_UNORM_S8_UINT, vk.VK_FORMAT_D32_SFLOAT };
        return vkimage.findsupportedformats(
            self.physicaldevice,
            &formats,
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
        );
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
    fn createtextureimage(self: *graphicalcontext) !void {
        var width: c_uint = undefined;
        var height: c_uint = undefined;

        const pixels: []u8 = try resourceloading.loadimage(
            self.allocator,
            &self.miplevels,
            &width,
            &height,
            "/home/evaniwin/Work/vulkan_zig/resources/teapot.png",
        );
        defer self.allocator.free(pixels);

        const imagesize: vk.VkDeviceSize = height * width * 4;

        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try vkbuffer.createbuffer(
            self.logicaldevice,
            self.physicaldevice,
            imagesize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );
        vkbuffer.copydatatobuffer(
            self.logicaldevice,
            stagingbuffermemory,
            imagesize,
            u8,
            pixels,
        );
        try vkimage.createimage(
            self.physicaldevice,
            self.logicaldevice,
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
        try vkimage.transitionimagelayout(
            self.commandpoolonetimecommand,
            self.textureimage,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            self.miplevels,
        );
        try vkimage.copybuffertoimage(
            self.commandpoolonetimecommand,
            stagingbuffer,
            self.textureimage,
            width,
            height,
        );

        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
        try vkimage.generatemipmaps(
            self.physicaldevice,
            self.commandpoolonetimecommand,
            self.textureimage,
            vk.VK_FORMAT_R8G8B8A8_SRGB,
            width,
            height,
            self.miplevels,
        );
    }
    fn createuniformbuffers_compute(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.uniformbufferobject_deltatime);
        const count = self.swapchain.images.len;
        self.uniformbuffer_compute = try self.allocator.alloc(vk.VkBuffer, count);
        self.uniformbuffermemory_compute = try self.allocator.alloc(vk.VkDeviceMemory, count);
        self.uniformbuffermemotymapped_compute = try self.allocator.alloc(?*anyopaque, count);
        for (0..count) |i| {
            try vkbuffer.createbuffer(
                self.logicaldevice,
                self.physicaldevice,
                buffersize,
                vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                &self.uniformbuffer_compute[i],
                &self.uniformbuffermemory_compute[i],
            );
            _ = vk.vkMapMemory(self.logicaldevice.device, self.uniformbuffermemory_compute[i], 0, buffersize, 0, &self.uniformbuffermemotymapped_compute[i]);
        }
    }
    fn createuniformbuffers(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.uniformbufferobject_view_lookat_projection_matrix);
        const count = self.swapchain.images.len;
        self.uniformbuffer_3d = try self.allocator.alloc(vk.VkBuffer, count);
        self.uniformbuffermemory_3d = try self.allocator.alloc(vk.VkDeviceMemory, count);
        self.uniformbuffermemotymapped_3d = try self.allocator.alloc(?*anyopaque, count);
        for (0..count) |i| {
            try vkbuffer.createbuffer(
                self.logicaldevice,
                self.physicaldevice,
                buffersize,
                vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                &self.uniformbuffer_3d[i],
                &self.uniformbuffermemory_3d[i],
            );
            _ = vk.vkMapMemory(self.logicaldevice.device, self.uniformbuffermemory_3d[i], 0, buffersize, 0, &self.uniformbuffermemotymapped_3d[i]);
        }
    }
    fn destroyuniformbuffers_compute(self: *graphicalcontext) void {
        for (0..self.uniformbuffer_compute.len) |i| {
            vk.vkDestroyBuffer(self.logicaldevice.device, self.uniformbuffer_compute[i], null);
            vk.vkFreeMemory(self.logicaldevice.device, self.uniformbuffermemory_compute[i], null);
        }
        self.allocator.free(self.uniformbuffer_compute);
        self.allocator.free(self.uniformbuffermemory_compute);
        self.allocator.free(self.uniformbuffermemotymapped_compute);
    }
    fn destroyuniformbuffers(self: *graphicalcontext) void {
        for (0..self.uniformbuffer_3d.len) |i| {
            vk.vkDestroyBuffer(self.logicaldevice.device, self.uniformbuffer_3d[i], null);
            vk.vkFreeMemory(self.logicaldevice.device, self.uniformbuffermemory_3d[i], null);
        }
        self.allocator.free(self.uniformbuffer_3d);
        self.allocator.free(self.uniformbuffermemory_3d);
        self.allocator.free(self.uniformbuffermemotymapped_3d);
    }
    fn createindexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(u32) * self.model.indices.len;
        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try vkbuffer.createbuffer(
            self.logicaldevice,
            self.physicaldevice,
            buffersize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );
        vkbuffer.copydatatobuffer(
            self.logicaldevice,
            stagingbuffermemory,
            buffersize,
            u32,
            self.model.indices,
        );
        try vkbuffer.createbuffer(
            self.logicaldevice,
            self.physicaldevice,
            buffersize,
            vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.indexbuffer,
            &self.indexbuffermemory,
        );
        try vkbuffer.copybuffertobuffer(self.commandpoolonetimecommand, stagingbuffer, self.indexbuffer, buffersize);
        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
    }
    fn destroyindexbuffer(self: *graphicalcontext) void {
        vk.vkDestroyBuffer(self.logicaldevice.device, self.indexbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.indexbuffermemory, null);
    }
    fn createvertexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(drawing.data) * self.model.vertices.len;
        var stagingbuffer: vk.VkBuffer = undefined;
        var stagingbuffermemory: vk.VkDeviceMemory = undefined;
        try vkbuffer.createbuffer(
            self.logicaldevice,
            self.physicaldevice,
            buffersize,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingbuffer,
            &stagingbuffermemory,
        );
        vkbuffer.copydatatobuffer(
            self.logicaldevice,
            stagingbuffermemory,
            buffersize,
            drawing.data,
            self.model.vertices,
        );
        try vkbuffer.createbuffer(
            self.logicaldevice,
            self.physicaldevice,
            buffersize,
            vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.vertexbuffer,
            &self.vertexbuffermemory,
        );
        try vkbuffer.copybuffertobuffer(self.commandpoolonetimecommand, stagingbuffer, self.vertexbuffer, buffersize);
        vk.vkDestroyBuffer(self.logicaldevice.device, stagingbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, stagingbuffermemory, null);
    }
    fn destroyvertexbuffer(self: *graphicalcontext) void {
        vk.vkDestroyBuffer(self.logicaldevice.device, self.vertexbuffer, null);
        vk.vkFreeMemory(self.logicaldevice.device, self.vertexbuffermemory, null);
    }

    fn destroysyncobjects(self: *graphicalcontext) void {
        for (0..self.swapchain.images.len) |i| {
            vk.vkDestroySemaphore(self.logicaldevice.device, self.imageavailablesephamores[i], null);
            vk.vkDestroySemaphore(self.logicaldevice.device, self.renderfinishedsephamores[i], null);
            vk.vkDestroyFence(self.logicaldevice.device, self.inflightfences[i], null);
            vk.vkDestroySemaphore(self.logicaldevice.device, self.computefinishedsephamores[i], null);
            vk.vkDestroyFence(self.logicaldevice.device, self.computeinflightfences[i], null);
            vk.vkDestroySemaphore(self.logicaldevice.device, self.computepreviousfinishedsephamores[i], null);
            vk.vkDestroySemaphore(self.logicaldevice.device, self.graphicspreviousfinishedsephamores[i], null);
        }
        self.allocator.free(self.imageavailablesephamores);
        self.allocator.free(self.renderfinishedsephamores);
        self.allocator.free(self.inflightfences);
        self.allocator.free(self.computefinishedsephamores);
        self.allocator.free(self.computeinflightfences);
        self.allocator.free(self.computepreviousfinishedsephamores);
        self.allocator.free(self.graphicspreviousfinishedsephamores);
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
        self.computefinishedsephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain.images.len);
        self.computeinflightfences = try self.allocator.alloc(vk.VkFence, self.swapchain.images.len);
        self.computepreviousfinishedsephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain.images.len);
        self.graphicspreviousfinishedsephamores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain.images.len);
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
            if (vk.vkCreateSemaphore(self.logicaldevice.device, &sephamorecreateinfo, null, &self.computefinishedsephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
            if (vk.vkCreateFence(self.logicaldevice.device, &fencecreateinfo, null, &self.computeinflightfences[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Cpu fence (render)", .{});
                return error.UnableToCreateFence;
            }
            if (vk.vkCreateSemaphore(self.logicaldevice.device, &sephamorecreateinfo, null, &self.computepreviousfinishedsephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
            if (vk.vkCreateSemaphore(self.logicaldevice.device, &sephamorecreateinfo, null, &self.graphicspreviousfinishedsephamores[i]) != vk.VK_SUCCESS) {
                std.log.err("Unable to Create Gpu Semaphore", .{});
                return error.UnableToCreateSemaphore;
            }
        }
    }

    fn createcommandpools(self: *graphicalcontext) !void {
        var commandpoolcreateparams: vkcommandbuffer.commandpoolcreateinfo = .{
            .allocator = self.allocator,
            .logicaldevice = self.logicaldevice,
            .queueFamilyIndex = self.logicaldevice.graphicsqueue.familyindex,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .commandbuffers = 4,
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
    fn createswapchainframebuffers_compute(self: *graphicalcontext) !void {
        self.swapchainframebuffers = try self.allocator.alloc(vk.VkFramebuffer, self.swapchainimageviews.imageviews.len);

        for (0..self.swapchainimageviews.imageviews.len) |i| {
            var attachments: [1]vk.VkImageView = .{self.swapchainimageviews.imageviews[i]};
            try vkimage.createframebuffer(
                self.logicaldevice,
                &self.swapchainframebuffers[i],
                self.renderpass,
                &attachments,
                self.swapchain.extent,
            );
        }
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
const vkdescriptor = @import("vulkan/descriptor.zig");
const vkcommandbuffer = @import("vulkan/commandbuffer.zig");
const vkbuffer = @import("vulkan/buffer.zig");
const resourceloading = @import("resourceloading.zig");
const mathmatrix = @import("mathmatrix.zig");
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
