pub fn createrenderpass(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    swapchain: *vkswapchain.swapchain,
    physicaldevice: *vkinstance.PhysicalDevice,
    depthformat: vk.VkFormat,
    renderpass: *vk.VkRenderPass,
) !void {
    var colorattachment: vk.VkAttachmentDescription = .{};
    colorattachment.format = swapchain.imageformat;
    colorattachment.samples = physicaldevice.MaxMsaaSamples;
    colorattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
    colorattachment.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorattachment.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorattachment.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    colorattachment.finalLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var depthattachment: vk.VkAttachmentDescription = .{};
    depthattachment.format = depthformat;
    depthattachment.samples = physicaldevice.MaxMsaaSamples;
    depthattachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
    depthattachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    depthattachment.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    depthattachment.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    depthattachment.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    depthattachment.finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    var colorattachmentresolve: vk.VkAttachmentDescription = .{};
    colorattachmentresolve.format = swapchain.imageformat;
    colorattachmentresolve.samples = vk.VK_SAMPLE_COUNT_1_BIT;
    colorattachmentresolve.loadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorattachmentresolve.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
    colorattachmentresolve.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorattachmentresolve.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorattachmentresolve.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    colorattachmentresolve.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    var colorattachmentrefrence: vk.VkAttachmentReference = .{};
    colorattachmentrefrence.attachment = 0;
    colorattachmentrefrence.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var depthattachmentrefrence: vk.VkAttachmentReference = .{};
    depthattachmentrefrence.attachment = 1;
    depthattachmentrefrence.layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    var colorattachmentresolverefrence: vk.VkAttachmentReference = .{};
    colorattachmentresolverefrence.attachment = 2;
    colorattachmentresolverefrence.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var subpass: vk.VkSubpassDescription = .{};
    subpass.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorattachmentrefrence;
    subpass.pDepthStencilAttachment = &depthattachmentrefrence;
    subpass.pResolveAttachments = &colorattachmentresolverefrence;

    var subpassdependency: vk.VkSubpassDependency = .{};
    subpassdependency.srcSubpass = vk.VK_SUBPASS_EXTERNAL;
    subpassdependency.dstSubpass = 0;
    subpassdependency.srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    subpassdependency.srcAccessMask = 0;
    subpassdependency.dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    subpassdependency.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

    var attachments: [3]vk.VkAttachmentDescription = .{ colorattachment, depthattachment, colorattachmentresolve };

    var subpasses: [1]vk.VkSubpassDescription = .{subpass};
    var subpassdependencies: [1]vk.VkSubpassDependency = .{subpassdependency};
    var renderpasscreateinfo: vk.VkRenderPassCreateInfo = .{};
    renderpasscreateinfo.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderpasscreateinfo.attachmentCount = attachments.len;
    renderpasscreateinfo.pAttachments = &attachments[0];
    renderpasscreateinfo.subpassCount = subpasses.len;
    renderpasscreateinfo.pSubpasses = &subpasses[0];
    renderpasscreateinfo.dependencyCount = subpassdependencies.len;
    renderpasscreateinfo.pDependencies = &subpassdependencies[0];

    if (vk.vkCreateRenderPass(logicaldevice.device, &renderpasscreateinfo, null, renderpass) != vk.VK_SUCCESS) {
        std.log.err("Unable To create Render Pass", .{});
        return error.UnableToCreateRenderPass;
    }
}
pub fn createrenderpass_compute(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    swapchain: *vkswapchain.swapchain,
    renderpass: *vk.VkRenderPass,
) !void {
    var colorattachment: vk.VkAttachmentDescription = .{};
    colorattachment.format = swapchain.imageformat;
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

    var attachments: [1]vk.VkAttachmentDescription = .{colorattachment};
    var renderpasscreateinfo: vk.VkRenderPassCreateInfo = .{};
    renderpasscreateinfo.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderpasscreateinfo.attachmentCount = attachments.len;
    renderpasscreateinfo.pAttachments = &attachments[0];
    renderpasscreateinfo.subpassCount = 1;
    renderpasscreateinfo.pSubpasses = &subpass;
    renderpasscreateinfo.dependencyCount = 1;
    renderpasscreateinfo.pDependencies = &subpassdependency;

    if (vk.vkCreateRenderPass(logicaldevice.device, &renderpasscreateinfo, null, renderpass) != vk.VK_SUCCESS) {
        std.log.err("Unable To create Render Pass", .{});
        return error.UnableToCreateRenderPass;
    }
}
pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const vkinstance = @import("instance.zig");
const vkswapchain = @import("swapchain.zig");
const drawing = @import("../drawing.zig");
const std = @import("std");
