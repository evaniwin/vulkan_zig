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

    pipelinelayout: vk.VkPipelineLayout,
    graphicspipeline: vk.VkPipeline,
    swapchainframebuffers: []vk.VkFramebuffer,
    commandpool: vk.VkCommandPool,
    commandpooldatatransfer: vk.VkCommandPool,
    commandbuffers: []vk.VkCommandBuffer,

    vertexbuffer: vk.VkBuffer,
    vertexbuffermemory: vk.VkDeviceMemory,
    indexbuffer: vk.VkBuffer,
    indexbuffermemory: vk.VkDeviceMemory,

    instanceextensions: *helper.extensionarray,
    imageavailablesephamores: []vk.VkSemaphore,
    renderfinishedsephamores: []vk.VkSemaphore,
    inflightfences: []vk.VkFence,
    datatransferfence: vk.VkFence,
    pub fn init(allocator: std.mem.Allocator, window: *vk.GLFWwindow) !*graphicalcontext {
        //allocate an instance of this struct
        const self: *graphicalcontext = allocator.create(graphicalcontext) catch |err| {
            std.log.err("Unable to allocate memory for vulkan instance: {s}", .{@errorName(err)});
            return err;
        };
        self.allocator = allocator;
        self.window = window;
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
        try createrenderpass(self);
        try creategraphicspipeline(self);
        try createframebuffers(self);
        try createcommandpools(self);
        try createsyncobjects(self);
        try createvertexbuffer(self);
        try createindexbuffer(self);
        try createcommandbuffer(self);
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        self.instanceextensions.free();
        destroysyncobjects(self);
        destroycommandpools(self);
        destroyframebuffers(self);
        vk.vkDestroyPipeline(self.device, self.graphicspipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipelinelayout, null);
        vk.vkDestroyRenderPass(self.device, self.renderpass, null);
        destroyimageviews(self);
        destroyswapchainimages(self);
        freeswapchain(self, self.swapchain);
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
        var clearcolor: vk.VkClearValue = .{ .color = vk.VkClearColorValue{ .int32 = .{ 0, 0, 0, 0 } } };
        renderpassbegininfo.clearValueCount = 1;
        renderpassbegininfo.pClearValues = &clearcolor;

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

        vk.vkCmdDrawIndexed(commandbuffer, indices.len, 1, 0, 0, 0);

        vk.vkCmdEndRenderPass(commandbuffer);

        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbufffer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
    }

    pub fn recreateswapchains(self: *graphicalcontext) !void {
        const oldswapchain: vk.VkSwapchainKHR = self.swapchain;
        const swapchainimageslen = self.swapchainimages.len;
        try createswapchain(self, oldswapchain);
        _ = vk.vkDeviceWaitIdle(self.device);
        destroyswapchainimages(self);
        destroyimageviews(self);
        vk.vkDestroyRenderPass(self.device, self.renderpass, null);
        destroyframebuffers(self);
        freeswapchain(self, oldswapchain);
        try getswapchainImages(self);
        try createimageviews(self);
        try createrenderpass(self);
        try createframebuffers(self);
        if (swapchainimageslen != self.swapchainimages.len) @panic("swap chain image length mismatch After Recreation");
    }
    fn createindexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(u32) * indices.len;
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
        std.mem.copyForwards(u32, ptr[0..indices.len], &indices);
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
    fn copybuffer(self: *graphicalcontext, srcbuffer: vk.VkBuffer, dstbuffer: vk.VkBuffer, size: vk.VkDeviceSize) !void {
        _ = vk.vkWaitForFences(
            self.device,
            1,
            &self.datatransferfence,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        _ = vk.vkResetFences(self.device, 1, &self.datatransferfence);
        var cmdbufferallocateinfo: vk.VkCommandBufferAllocateInfo = .{};
        cmdbufferallocateinfo.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cmdbufferallocateinfo.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        cmdbufferallocateinfo.commandPool = self.commandpooldatatransfer;
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

        var copyregion: vk.VkBufferCopy = .{};
        copyregion.srcOffset = 0;
        copyregion.dstOffset = 0;
        copyregion.size = size;
        vk.vkCmdCopyBuffer(commandbuffer, srcbuffer, dstbuffer, 1, &copyregion);
        if (vk.vkEndCommandBuffer(commandbuffer) != vk.VK_SUCCESS) {
            std.log.err("Unable to End Recording Commandbufffer datatransfer", .{});
            return error.FailedToEndRecordingCommandBuffer;
        }
        var submitinfo: vk.VkSubmitInfo = .{};
        submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitinfo.commandBufferCount = 1;
        submitinfo.pCommandBuffers = &commandbuffer;

        if (vk.vkQueueSubmit(self.graphicsqueue.queue, 1, &submitinfo, self.datatransferfence) != vk.VK_SUCCESS) {
            std.log.err("Unable to Submit Queue", .{});
            return error.QueueSubmissionFailed;
        }
        _ = vk.vkWaitForFences(
            self.device,
            1,
            &self.datatransferfence,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        vk.vkFreeCommandBuffers(self.device, self.commandpooldatatransfer, 1, &commandbuffer);
    }
    fn createvertexbuffer(self: *graphicalcontext) !void {
        const buffersize = @sizeOf(data) * vertices.len;
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
        const ptr: [*]data = @ptrCast(@alignCast(memdata));
        std.mem.copyForwards(data, ptr[0..vertices.len], &vertices);
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
        vk.vkDestroyFence(self.device, self.datatransferfence, null);
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
        if (vk.vkCreateFence(self.device, &fencecreateinfo, null, &self.datatransferfence) != vk.VK_SUCCESS) {
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

        if (vk.vkCreateCommandPool(self.device, &commandpooldatatransfercreateinfo, null, &self.commandpooldatatransfer) != vk.VK_SUCCESS) {
            std.log.err("Unable to create Command Pool", .{});
            return error.CommandPoolCreationFailed;
        }
    }
    fn destroycommandpools(self: *graphicalcontext) void {
        vk.vkDestroyCommandPool(self.device, self.commandpool, null);
        vk.vkDestroyCommandPool(self.device, self.commandpooldatatransfer, null);
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
            var attachments: [1]vk.VkImageView = .{self.swapchainimageviews[i]};
            var framebuffercreateinfo: vk.VkFramebufferCreateInfo = .{};
            framebuffercreateinfo.sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            framebuffercreateinfo.renderPass = self.renderpass;
            framebuffercreateinfo.attachmentCount = 1;
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

        var colorattachmentrefrence: vk.VkAttachmentReference = .{};
        colorattachmentrefrence.attachment = 0;
        colorattachmentrefrence.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        var subpass: vk.VkSubpassDescription = .{};
        subpass.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = &colorattachmentrefrence;

        var subpassdependency: vk.VkSubpassDependency = .{};
        subpassdependency.srcSubpass = vk.VK_SUBPASS_EXTERNAL;
        subpassdependency.dstSubpass = 0;
        subpassdependency.srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        subpassdependency.srcAccessMask = 0;
        subpassdependency.dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        subpassdependency.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        var renderpasscreateinfo: vk.VkRenderPassCreateInfo = .{};
        renderpasscreateinfo.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        renderpasscreateinfo.attachmentCount = 1;
        renderpasscreateinfo.pAttachments = &colorattachment;
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

        var bindingdescription = vertexbufferconfig.getbindingdescription(data);
        var attributedescribtions = vertexbufferconfig.getattributedescruptions(data);
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
        rasterizer.frontFace = vk.VK_FRONT_FACE_CLOCKWISE;
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

        //placeholder for depth and stencil tests

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

        var pipelinelayoutcreateinfo: vk.VkPipelineLayoutCreateInfo = .{};
        pipelinelayoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipelinelayoutcreateinfo.setLayoutCount = 0;
        pipelinelayoutcreateinfo.pSetLayouts = null;
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
        graphicspipelinecreateinfo.pDepthStencilState = null;
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
            var createinfo: vk.VkImageViewCreateInfo = .{};
            createinfo.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            createinfo.image = self.swapchainimages[i];

            createinfo.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
            createinfo.format = self.swapchainimageformat;

            createinfo.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            createinfo.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            createinfo.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            createinfo.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;

            createinfo.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
            createinfo.subresourceRange.baseMipLevel = 0;
            createinfo.subresourceRange.levelCount = 1;
            createinfo.subresourceRange.baseArrayLayer = 0;
            createinfo.subresourceRange.layerCount = 1;

            if (vk.vkCreateImageView(self.device, &createinfo, null, &self.swapchainimageviews[i]) != vk.VK_SUCCESS) {
                std.log.err("Failed to Create image Views", .{});
                return error.FailedToCreateImageView;
            }
        }
    }
    fn destroyimageviews(self: *graphicalcontext) void {
        for (self.swapchainimageviews) |imageview| {
            vk.vkDestroyImageView(self.device, imageview, null);
        }
        self.allocator.free(self.swapchainimageviews);
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
const data = extern struct {
    vertex: [3]f32,
    color: [3]f32,
};
const vertices: [3]data = .{
    .{ .vertex = .{ 0.0, -0.5, 0.0 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .vertex = .{ 0.5, 0.5, 0.0 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .vertex = .{ -0.5, 0.5, 0.0 }, .color = .{ 0.0, 0.0, 1.0 } },
};
const indices: [3]u32 = .{ 0, 1, 2 };
const vertexbufferconfig = struct {
    pub fn getbindingdescription(T: type) vk.VkVertexInputBindingDescription {
        var bindingdescription: vk.VkVertexInputBindingDescription = .{};
        bindingdescription.binding = 0;
        bindingdescription.stride = @sizeOf(T);
        bindingdescription.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
        return bindingdescription;
    }
    pub fn getattributedescruptions(T: type) [2]vk.VkVertexInputAttributeDescription {
        var attributedescriptions: [2]vk.VkVertexInputAttributeDescription = undefined;
        attributedescriptions[0].binding = 0;
        attributedescriptions[0].location = 0;
        attributedescriptions[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[0].offset = @offsetOf(T, "vertex");
        attributedescriptions[1].binding = 0;
        attributedescriptions[1].location = 1;
        attributedescriptions[1].format = vk.VK_FORMAT_R32G32B32_SFLOAT;
        attributedescriptions[1].offset = @offsetOf(T, "color");
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

pub const vk = graphics.vk;
const graphics = @import("graphics.zig");
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
