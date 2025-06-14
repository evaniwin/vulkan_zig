const triangle_frag = @embedFile("../spirv/triangle_frag.spv");
const triangle_vert = @embedFile("../spirv/triangle_vert.spv");
fn createshadermodule(code: []const u32, logicaldevice: *vklogicaldevice.LogicalDevice) !vk.VkShaderModule {
    var createinfo: vk.VkShaderModuleCreateInfo = .{};
    createinfo.sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createinfo.codeSize = code.len * 4;
    createinfo.pCode = @ptrCast(code);

    var shadermodule: vk.VkShaderModule = undefined;
    if (vk.vkCreateShaderModule(logicaldevice.device, &createinfo, null, &shadermodule) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create Shader Module", .{});
        return error.ShaderModuleCreationFailed;
    }
    return shadermodule;
}
pub fn creategraphicspipeline(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    renderpass: vk.VkRenderPass,
    physicaldevice: *vkinstance.PhysicalDevice,
    descriptorsetlayout: vk.VkDescriptorSetLayout,
    pipelinelayout: *vk.VkPipelineLayout,
    graphicspipeline: *vk.VkPipeline,
) !void {
    //cast a slice of u8 to slice of u32
    const vertcodeslice = @as([*]const u32, @ptrCast(@alignCast(triangle_vert)))[0 .. triangle_vert.len / @sizeOf(u32)];
    const fragcodeslice = @as([*]const u32, @ptrCast(@alignCast(triangle_frag)))[0 .. triangle_frag.len / @sizeOf(u32)];

    const vertshadermodule = try createshadermodule(vertcodeslice, logicaldevice);
    const fragshadermodule = try createshadermodule(fragcodeslice, logicaldevice);

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

    //viewport and scissor set to null for dynamic
    var viewportstatecreateinfo: vk.VkPipelineViewportStateCreateInfo = .{};
    viewportstatecreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportstatecreateinfo.viewportCount = 1;
    viewportstatecreateinfo.pViewports = null;
    viewportstatecreateinfo.scissorCount = 1;
    viewportstatecreateinfo.pScissors = null;

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
    multisampling.sampleShadingEnable = physicaldevice.physicaldevicefeatures.sampleRateShading;
    multisampling.rasterizationSamples = physicaldevice.MaxMsaaSamples;
    multisampling.minSampleShading = 0.2;
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

    var setlayouts: [1]vk.VkDescriptorSetLayout = .{descriptorsetlayout};
    var pipelinelayoutcreateinfo: vk.VkPipelineLayoutCreateInfo = .{};
    pipelinelayoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelinelayoutcreateinfo.setLayoutCount = 1;
    pipelinelayoutcreateinfo.pSetLayouts = &setlayouts[0];
    pipelinelayoutcreateinfo.pushConstantRangeCount = 0;
    pipelinelayoutcreateinfo.pPushConstantRanges = null;

    if (vk.vkCreatePipelineLayout(logicaldevice.device, &pipelinelayoutcreateinfo, null, pipelinelayout) != vk.VK_SUCCESS) {
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
    graphicspipelinecreateinfo.layout = pipelinelayout.*;
    graphicspipelinecreateinfo.renderPass = renderpass;
    graphicspipelinecreateinfo.subpass = 0;
    graphicspipelinecreateinfo.basePipelineHandle = null;
    graphicspipelinecreateinfo.basePipelineIndex = -1;

    if (vk.vkCreateGraphicsPipelines(logicaldevice.device, null, 1, &graphicspipelinecreateinfo, null, graphicspipeline) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create Pipeline", .{});
        return error.PipelineCreationFailed;
    }

    vk.vkDestroyShaderModule(logicaldevice.device, vertshadermodule, null);
    vk.vkDestroyShaderModule(logicaldevice.device, fragshadermodule, null);
}
pub fn createdescriptorsetlayout(logicaldevice: *vklogicaldevice.LogicalDevice, descriptorsetlayout: *vk.VkDescriptorSetLayout) !void {
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

    if (vk.vkCreateDescriptorSetLayout(logicaldevice.device, &layoutcreateinfo, null, descriptorsetlayout) != vk.VK_SUCCESS) {
        std.log.err("Unable to create Descriptor Set Layout", .{});
        return error.FailedToCreateDescriptorSetLayout;
    }
}
pub fn destroydescriptorsetlayout(logicaldevice: *vklogicaldevice.LogicalDevice, descriptorsetlayout: vk.VkDescriptorSetLayout) void {
    vk.vkDestroyDescriptorSetLayout(logicaldevice.device, descriptorsetlayout, null);
}
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
pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const vkinstance = @import("instance.zig");
const drawing = @import("../drawing.zig");
const std = @import("std");
