const triangle = @embedFile("../spirv/triangle.spv");
const point = @embedFile("../spirv/point.spv");

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
    physicaldevice: *vkinstance.PhysicalDevice,
    descriptorsetlayout: vk.VkDescriptorSetLayout,
    swapchain: *vkswapchain.swapchain,
    depthformat: vk.VkFormat,
    stencilformat: vk.VkFormat,
    pipelinelayout: *vk.VkPipelineLayout,
    pipeline: *vk.VkPipeline,
) !void {
    //cast a slice of u8 to slice of u32
    const codeslice = @as([*]const u32, @ptrCast(@alignCast(triangle)))[0 .. triangle.len / @sizeOf(u32)];

    const shadermodule = try createshadermodule(codeslice, logicaldevice);

    var vertshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
    vertshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    vertshadercreateinfo.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
    vertshadercreateinfo.module = shadermodule;
    vertshadercreateinfo.pName = "vertMain";

    var fragshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
    fragshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    fragshadercreateinfo.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
    fragshadercreateinfo.module = shadermodule;
    fragshadercreateinfo.pName = "fragMain";

    var shaderstages: [2]vk.VkPipelineShaderStageCreateInfo = .{ vertshadercreateinfo, fragshadercreateinfo };
    _ = &shaderstages;

    var dynamicstates: [2]vk.VkDynamicState = .{ vk.VK_DYNAMIC_STATE_VIEWPORT, vk.VK_DYNAMIC_STATE_SCISSOR };
    var dynamicstatecreateinfo: vk.VkPipelineDynamicStateCreateInfo = .{};
    dynamicstatecreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamicstatecreateinfo.dynamicStateCount = dynamicstates.len;
    dynamicstatecreateinfo.pDynamicStates = &dynamicstates[0];

    var bindingdescription = drawing.data.getbindingdescription();
    var attributedescribtions = drawing.data.getattributedescruptions();
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

    var pipelinerenderingcreateinfo: vk.VkPipelineRenderingCreateInfo = .{};
    pipelinerenderingcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    pipelinerenderingcreateinfo.pNext = null;
    pipelinerenderingcreateinfo.colorAttachmentCount = 1;
    pipelinerenderingcreateinfo.pColorAttachmentFormats = &swapchain.imageformat;
    pipelinerenderingcreateinfo.depthAttachmentFormat = depthformat;
    pipelinerenderingcreateinfo.stencilAttachmentFormat = stencilformat;
    //pipelinerenderingcreateinfo.viewMask=;

    var graphicspipelinecreateinfo: vk.VkGraphicsPipelineCreateInfo = .{};
    graphicspipelinecreateinfo.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    graphicspipelinecreateinfo.pNext = &pipelinerenderingcreateinfo;
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
    graphicspipelinecreateinfo.renderPass = null;
    graphicspipelinecreateinfo.subpass = 0;
    graphicspipelinecreateinfo.basePipelineHandle = null;
    graphicspipelinecreateinfo.basePipelineIndex = -1;

    if (vk.vkCreateGraphicsPipelines(logicaldevice.device, null, 1, &graphicspipelinecreateinfo, null, pipeline) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create Pipeline", .{});
        return error.PipelineCreationFailed;
    }

    vk.vkDestroyShaderModule(logicaldevice.device, shadermodule, null);
}
pub fn creategraphicspipeline_compute(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    swapchain: *vkswapchain.swapchain,
    pipelinelayout: *vk.VkPipelineLayout,
    pipeline: *vk.VkPipeline,
) !void {
    //cast a slice of u8 to slice of u32
    const codeslice = @as([*]const u32, @ptrCast(@alignCast(point)))[0 .. point.len / @sizeOf(u32)];

    const shadermodule = try createshadermodule(codeslice, logicaldevice);

    var vertshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
    vertshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    vertshadercreateinfo.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
    vertshadercreateinfo.module = shadermodule;
    vertshadercreateinfo.pName = "vertMain";

    var fragshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
    fragshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    fragshadercreateinfo.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
    fragshadercreateinfo.module = shadermodule;
    fragshadercreateinfo.pName = "fragMain";

    var shaderstages: [2]vk.VkPipelineShaderStageCreateInfo = .{ vertshadercreateinfo, fragshadercreateinfo };
    _ = &shaderstages;

    var dynamicstates: [2]vk.VkDynamicState = .{
        vk.VK_DYNAMIC_STATE_VIEWPORT,
        vk.VK_DYNAMIC_STATE_SCISSOR,
    };
    var dynamicstatecreateinfo: vk.VkPipelineDynamicStateCreateInfo = .{};
    dynamicstatecreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamicstatecreateinfo.dynamicStateCount = dynamicstates.len;
    dynamicstatecreateinfo.pDynamicStates = &dynamicstates[0];

    var bindingdescription = drawing.points.getbindingdescription();
    var attributedescribtions = drawing.points.getattributedescruptions();
    //this structure describes the format of the vertex data that will be passed to the vertex shader
    var vertexinputinfo: vk.VkPipelineVertexInputStateCreateInfo = .{};
    vertexinputinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertexinputinfo.vertexBindingDescriptionCount = 1;
    vertexinputinfo.pVertexBindingDescriptions = &bindingdescription;
    vertexinputinfo.vertexAttributeDescriptionCount = attributedescribtions.len;
    vertexinputinfo.pVertexAttributeDescriptions = &attributedescribtions[0];

    var inputassembly: vk.VkPipelineInputAssemblyStateCreateInfo = .{};
    inputassembly.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputassembly.topology = vk.VK_PRIMITIVE_TOPOLOGY_POINT_LIST;
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
    multisampling.sampleShadingEnable = vk.VK_FALSE;
    multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;
    multisampling.minSampleShading = 0.2;
    multisampling.pSampleMask = null;
    multisampling.alphaToCoverageEnable = vk.VK_FALSE;
    multisampling.alphaToOneEnable = vk.VK_FALSE;

    var colorblendattachment: vk.VkPipelineColorBlendAttachmentState = .{};
    colorblendattachment.colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT;
    colorblendattachment.blendEnable = vk.VK_TRUE;
    colorblendattachment.srcColorBlendFactor = vk.VK_BLEND_FACTOR_SRC_ALPHA;
    colorblendattachment.dstColorBlendFactor = vk.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
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

    if (vk.vkCreatePipelineLayout(logicaldevice.device, &pipelinelayoutcreateinfo, null, pipelinelayout) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create Pipeline Layout", .{});
        return error.PipelineCreationFailedLayout;
    }
    var pipelinerenderingcreateinfo: vk.VkPipelineRenderingCreateInfo = .{};
    pipelinerenderingcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    pipelinerenderingcreateinfo.pNext = null;
    pipelinerenderingcreateinfo.colorAttachmentCount = 1;
    pipelinerenderingcreateinfo.pColorAttachmentFormats = &swapchain.imageformat;
    //pipelinerenderingcreateinfo.viewMask=;

    var graphicspipelinecreateinfo: vk.VkGraphicsPipelineCreateInfo = .{};
    graphicspipelinecreateinfo.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    graphicspipelinecreateinfo.pNext = &pipelinerenderingcreateinfo;
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
    graphicspipelinecreateinfo.layout = pipelinelayout.*;
    graphicspipelinecreateinfo.renderPass = null;
    graphicspipelinecreateinfo.subpass = 0;
    graphicspipelinecreateinfo.basePipelineHandle = null;
    graphicspipelinecreateinfo.basePipelineIndex = -1;

    if (vk.vkCreateGraphicsPipelines(logicaldevice.device, null, 1, &graphicspipelinecreateinfo, null, pipeline) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create Pipeline", .{});
        return error.PipelineCreationFailed;
    }

    vk.vkDestroyShaderModule(logicaldevice.device, shadermodule, null);
}
pub fn createcomputepipeline(
    logicaldevice: *vklogicaldevice.LogicalDevice,
    descriptorsetlayout: vk.VkDescriptorSetLayout,
    pipelinelayout: *vk.VkPipelineLayout,
    pipeline: *vk.VkPipeline,
) !void {
    const computecodeslice = @as([*]const u32, @ptrCast(@alignCast(point)))[0 .. point.len / @sizeOf(u32)];

    const computeshadermodule = try createshadermodule(computecodeslice, logicaldevice);

    var computeshadercreateinfo: vk.VkPipelineShaderStageCreateInfo = .{};
    computeshadercreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    computeshadercreateinfo.stage = vk.VK_SHADER_STAGE_COMPUTE_BIT;
    computeshadercreateinfo.module = computeshadermodule;
    computeshadercreateinfo.pName = "compMain";

    var setlayouts: [1]vk.VkDescriptorSetLayout = .{descriptorsetlayout};
    var pipelinelayoutcreateinfo: vk.VkPipelineLayoutCreateInfo = .{};
    pipelinelayoutcreateinfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelinelayoutcreateinfo.setLayoutCount = 1;
    pipelinelayoutcreateinfo.pSetLayouts = &setlayouts[0];
    pipelinelayoutcreateinfo.pushConstantRangeCount = 0;
    pipelinelayoutcreateinfo.pPushConstantRanges = null;
    pipelinelayoutcreateinfo.flags = 0;
    pipelinelayoutcreateinfo.pNext = null;

    if (vk.vkCreatePipelineLayout(logicaldevice.device, &pipelinelayoutcreateinfo, null, pipelinelayout) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create Pipeline Layout", .{});
        return error.PipelineCreationFailedLayout;
    }
    var pipelinecreateinfo: vk.VkComputePipelineCreateInfo = .{};
    pipelinecreateinfo.sType = vk.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
    pipelinecreateinfo.pNext = null;
    pipelinecreateinfo.flags = 0;
    pipelinecreateinfo.stage = computeshadercreateinfo;
    pipelinecreateinfo.layout = pipelinelayout.*;
    pipelinecreateinfo.basePipelineHandle = null;
    pipelinecreateinfo.basePipelineIndex = 0;

    if (vk.vkCreateComputePipelines(logicaldevice.device, null, 1, &pipelinecreateinfo, null, pipeline) != vk.VK_SUCCESS) {
        std.log.err("Unable to Create compute Pipeline", .{});
        return error.PipelineCreationFailed;
    }
    vk.vkDestroyShaderModule(logicaldevice.device, computeshadermodule, null);
}

pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const vkinstance = @import("instance.zig");
const drawing = @import("../drawing.zig");
const vkswapchain = @import("swapchain.zig");
const std = @import("std");
