fn keycallback(_: ?*vk.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = scancode;
    _ = mods;
    if ((key == vk.GLFW_KEY_ESCAPE) and (action == vk.GLFW_PRESS)) {
        main.running = false;
    }

    if (action == vk.GLFW_PRESS or action == vk.GLFW_REPEAT) {
        if ((key == vk.GLFW_KEY_UP)) {
            std.debug.print("up arrow key pressed\n", .{});
        }
        if ((key == vk.GLFW_KEY_DOWN)) {
            std.debug.print("down arrow key pressed\n", .{});
        }
        if ((key == vk.GLFW_KEY_RIGHT)) {
            std.debug.print("right arrow key pressed\n", .{});
        }
        if ((key == vk.GLFW_KEY_LEFT)) {
            std.debug.print("left arrow key pressed\n", .{});
        }
        if (key == vk.GLFW_KEY_HOME) {
            std.debug.print("home key pressed\n", .{});
        }
        if (key == vk.GLFW_KEY_TAB) {
            std.debug.print("tab key pressed\n", .{});
        }
    }
}

fn mousebuttoncallback(_: ?*vk.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;
    if (button == vk.GLFW_MOUSE_BUTTON_LEFT and action == vk.GLFW_PRESS) {
        std.debug.print("left mouse button clicked\n", .{});
    }
}

fn framebuffersizecallback(_: ?*vk.GLFWwindow, _: c_int, _: c_int) callconv(.c) void {
    recreateswapchain = true;
}

fn errorcallback(err: c_int, decsription: [*c]const u8) callconv(.c) void {
    std.log.err("glfw error code{d}--{any}", .{ err, decsription });
}
var cursorpos: [2]f64 = .{ 0, 0 };
fn cursorposcallback(_: ?*vk.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    cursorpos = .{ xpos, ypos };
    std.debug.print("x:{d} y:{d}\n", .{ xpos, ypos });
}
fn windowhandler(window: ?*vk.GLFWwindow) void {
    if (vk.glfwWindowShouldClose(window) != 0) {
        std.log.warn("stop condition", .{});
        main.running = false;
    }
}
fn viewportsizeupdate(window: ?*vk.GLFWwindow, vkinstance: *utilty.graphicalcontext) void {
    _ = window;
    //var framebuffer: [2]c_int = undefined;
    //vk.glfwGetFramebufferSize(window, &framebuffer[0], &framebuffer[1]);
    if (recreateswapchain) {
        vkinstance.recreateswapchains() catch |err| {
            std.log.err("Unable to recreate swapchain: {s}", .{@errorName(err)});
            return;
        };
        recreateswapchain = false;
    }
}
var timer: std.time.Timer = undefined;
const app_name = "vulkan-zig triangle example";
pub fn draw() !void {
    std.log.info("render Thread started\n", .{});
    defer std.log.info("render Thread exited\n", .{});
    timer = try std.time.Timer.start();
    if (vk.glfwInit() != vk.GLFW_TRUE) return error.GlfwInitFailed;
    defer vk.glfwTerminate();

    if (vk.glfwVulkanSupported() != vk.GLFW_TRUE) {
        std.log.err("GLFW could not find libvulkan", .{});
        return error.NoVulkan;
    }

    vk.glfwWindowHint(vk.GLFW_CLIENT_API, vk.GLFW_NO_API);
    //vk.glfwWindowHint(vk.GLFW_RESIZABLE, vk.GLFW_FALSE);
    const window = vk.glfwCreateWindow(
        @intCast(main.viewportsize[0]),
        @intCast(main.viewportsize[1]),
        app_name,
        null,
        null,
    ) orelse return error.WindowInitFailed;
    defer vk.glfwDestroyWindow(window);

    //set various callback functions
    _ = vk.glfwSetErrorCallback(errorcallback);
    _ = vk.glfwSetKeyCallback(window, keycallback);
    _ = vk.glfwSetCursorPosCallback(window, cursorposcallback);
    _ = vk.glfwSetMouseButtonCallback(window, mousebuttoncallback);
    _ = vk.glfwSetFramebufferSizeCallback(window, framebuffersizecallback);
    const vkinstance = utilty.graphicalcontext.init(main.allocator, window) catch |err| {
        std.log.err("Unable instance creation failed: {s}", .{@errorName(err)});
        return;
    };
    defer vkinstance.deinit();
    try drawframec(vkinstance, true);
    while (main.running) {
        //poll events
        vk.glfwPollEvents();
        try drawframec(vkinstance, false);
        windowhandler(window);
        viewportsizeupdate(window, vkinstance);
    }
    _ = vk.vkDeviceWaitIdle(vkinstance.logicaldevice.device);
}
var recreateswapchain: bool = false;
var currentframe: usize = 0;
var previousframe: usize = 0;
fn drawframec(vkinstance: *utilty.graphicalcontext, firstframe: bool) !void {
    //wait for compute task to finish
    _ = vk.vkWaitForFences(
        vkinstance.logicaldevice.device,
        1,
        &vkinstance.computeinflightfences[currentframe],
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );
    //update the uniform buffer with the new delta time reset compute fences and command buffers
    try updateuniformbuffer_time(currentframe, vkinstance);
    _ = vk.vkResetFences(vkinstance.logicaldevice.device, 1, &vkinstance.computeinflightfences[currentframe]);
    _ = vk.vkResetCommandBuffer(vkinstance.commandpool.commandbuffers[1][currentframe], 0);
    //issue compute commands
    try vkinstance.recordcomputecommandbuffer(vkinstance.commandpool.commandbuffers[1][currentframe], @intCast(currentframe));
    var computesignalsemaphores: [2]vk.VkSemaphore = .{ vkinstance.computefinishedsephamores[currentframe], vkinstance.computepreviousfinishedsephamores[currentframe] };
    var computewaitsemaphores: [1]vk.VkSemaphore = .{vkinstance.computepreviousfinishedsephamores[previousframe]};
    var computewaitstages: [1]vk.VkPipelineStageFlags = .{
        vk.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
    };
    var submitinfo: vk.VkSubmitInfo = .{};
    submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    if (firstframe) {
        submitinfo.waitSemaphoreCount = 0;
    } else submitinfo.waitSemaphoreCount = computewaitsemaphores.len;
    submitinfo.pWaitDstStageMask = &computewaitstages[0];
    submitinfo.pWaitSemaphores = &computewaitsemaphores[0];
    submitinfo.signalSemaphoreCount = computesignalsemaphores.len;
    submitinfo.pSignalSemaphores = &computesignalsemaphores[0];
    submitinfo.commandBufferCount = 1;
    submitinfo.pCommandBuffers = &vkinstance.commandpool.commandbuffers[1][currentframe];
    if (vk.vkQueueSubmit(vkinstance.logicaldevice.computequeue.queue, 1, &submitinfo, vkinstance.computeinflightfences[currentframe]) != vk.VK_SUCCESS) {
        std.log.err("Unable to Submit Queue", .{});
        return error.QueueSubmissionFailed;
    }

    //wait for graphics task to finish
    _ = vk.vkWaitForFences(
        vkinstance.logicaldevice.device,
        1,
        &vkinstance.inflightfences[currentframe],
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );
    //retrive new image from frame buffer
    var imageindex: u32 = undefined;
    var result = vk.vkAcquireNextImageKHR(
        vkinstance.logicaldevice.device,
        vkinstance.swapchain.swapchain,
        std.math.maxInt(u64),
        vkinstance.imageavailablesephamores[currentframe],
        null,
        &imageindex,
    );
    if (result == vk.VK_ERROR_OUT_OF_DATE_KHR) {
        try vkinstance.recreateswapchains();
        return;
    } else if (result != vk.VK_SUCCESS and result != vk.VK_SUBOPTIMAL_KHR) {
        std.log.err("unable to obtain swapchain image acquire", .{});
        return;
    }
    try updateuniformbuffer_matrix(imageindex, vkinstance);
    //reset graphics fences and command buffer
    _ = vk.vkResetFences(vkinstance.logicaldevice.device, 1, &vkinstance.inflightfences[currentframe]);
    _ = vk.vkResetCommandBuffer(vkinstance.commandpool.commandbuffers[0][currentframe], 0);
    //issue commands to graphics queue
    try vkinstance.recordcommandbuffer(
        vkinstance.commandpool.commandbuffers[0][currentframe],
        imageindex,
        @intCast(currentframe),
    );

    var graphicswaitsemaphores: [3]vk.VkSemaphore = .{
        vkinstance.computefinishedsephamores[currentframe],
        vkinstance.imageavailablesephamores[currentframe],
        vkinstance.graphicspreviousfinishedsephamores[previousframe],
    };
    var waitstages: [3]vk.VkPipelineStageFlags = .{
        vk.VK_PIPELINE_STAGE_VERTEX_INPUT_BIT,
        vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
    };
    var graphicsignalsemaphores: [2]vk.VkSemaphore = .{
        vkinstance.renderfinishedsephamores[imageindex],
        vkinstance.graphicspreviousfinishedsephamores[currentframe],
    };

    submitinfo = .{};
    submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    if (firstframe) {
        submitinfo.waitSemaphoreCount = 2;
    } else submitinfo.waitSemaphoreCount = graphicswaitsemaphores.len;
    submitinfo.pWaitSemaphores = &graphicswaitsemaphores[0];
    submitinfo.pWaitDstStageMask = &waitstages[0];
    submitinfo.commandBufferCount = 1;
    submitinfo.pCommandBuffers = &vkinstance.commandpool.commandbuffers[0][currentframe];
    submitinfo.signalSemaphoreCount = graphicsignalsemaphores.len;
    submitinfo.pSignalSemaphores = &graphicsignalsemaphores[0];
    if (vk.vkQueueSubmit(vkinstance.logicaldevice.graphicsqueue.queue, 1, &submitinfo, vkinstance.inflightfences[currentframe]) != vk.VK_SUCCESS) {
        std.log.err("Unable to Submit Queue", .{});
        return error.QueueSubmissionFailed;
    }
    //issue commands to present queue
    var presentwaitsemaphores: [1]vk.VkSemaphore = .{
        vkinstance.renderfinishedsephamores[imageindex],
    };
    var swapchains: [1]vk.VkSwapchainKHR = .{
        vkinstance.swapchain.swapchain,
    };
    var presentinfo: vk.VkPresentInfoKHR = .{};
    presentinfo.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentinfo.waitSemaphoreCount = 1;
    presentinfo.pWaitSemaphores = &presentwaitsemaphores[0];
    presentinfo.swapchainCount = 1;
    presentinfo.pSwapchains = &swapchains[0];
    presentinfo.pImageIndices = &imageindex;
    presentinfo.pResults = null;
    result = vk.vkQueuePresentKHR(vkinstance.logicaldevice.presentqueue.queue, &presentinfo);
    if (result == vk.VK_ERROR_OUT_OF_DATE_KHR and result != vk.VK_SUBOPTIMAL_KHR) {
        try vkinstance.recreateswapchains();
        return;
    } else if (result != vk.VK_SUCCESS and result != vk.VK_SUBOPTIMAL_KHR) {
        std.log.err("unable to obtain swapchain image present", .{});
        return;
    }
    //update current frame with values from 0 to current frame
    previousframe = currentframe;
    currentframe = (currentframe + 1) % @min(vkinstance.swapchain.images.len, utilty.MAX_FRAMES_IN_FLIGHT);
}
fn drawframe(vkinstance: *utilty.graphicalcontext) !void {
    _ = vk.vkWaitForFences(
        vkinstance.logicaldevice.device,
        1,
        &vkinstance.inflightfences[currentframe],
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );
    var imageindex: u32 = undefined;
    var result = vk.vkAcquireNextImageKHR(
        vkinstance.logicaldevice.device,
        vkinstance.swapchain.swapchain,
        std.math.maxInt(u64),
        vkinstance.imageavailablesephamores[currentframe],
        null,
        &imageindex,
    );
    if (result == vk.VK_ERROR_OUT_OF_DATE_KHR) {
        try vkinstance.recreateswapchains();
        return;
    } else if (result != vk.VK_SUCCESS and result != vk.VK_SUBOPTIMAL_KHR) {
        std.log.err("unable to obtain swapchain image acquire", .{});
        return;
    }
    try updateuniformbuffer_matrix(currentframe, vkinstance);
    _ = vk.vkResetFences(vkinstance.logicaldevice.device, 1, &vkinstance.inflightfences[currentframe]);
    _ = vk.vkResetCommandBuffer(vkinstance.commandpool.commandbuffers[0][currentframe], 0);
    //try vkinstance.recordcommandbuffer(vkinstance.commandpool.commandbuffers[0][currentframe], imageindex);
    try vkinstance.recordcommandbuffer_compute(vkinstance.commandpool.commandbuffers[0][currentframe], imageindex);

    var submitinfo: vk.VkSubmitInfo = .{};
    submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;

    var waitsemaphores: [1]vk.VkSemaphore = .{vkinstance.imageavailablesephamores[currentframe]};
    var waitstages: [1]vk.VkPipelineStageFlags = .{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submitinfo.waitSemaphoreCount = 1;
    submitinfo.pWaitSemaphores = &waitsemaphores[0];
    submitinfo.pWaitDstStageMask = &waitstages[0];
    submitinfo.commandBufferCount = 1;
    submitinfo.pCommandBuffers = &vkinstance.commandpool.commandbuffers[0][currentframe];

    var signalsemaphores: [1]vk.VkSemaphore = .{vkinstance.renderfinishedsephamores[imageindex]};
    submitinfo.signalSemaphoreCount = 1;
    submitinfo.pSignalSemaphores = &signalsemaphores[0];

    if (vk.vkQueueSubmit(vkinstance.logicaldevice.graphicsqueue.queue, 1, &submitinfo, vkinstance.inflightfences[currentframe]) != vk.VK_SUCCESS) {
        std.log.err("Unable to Submit Queue", .{});
        return error.QueueSubmissionFailed;
    }

    var presentinfo: vk.VkPresentInfoKHR = .{};
    presentinfo.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentinfo.waitSemaphoreCount = 1;
    presentinfo.pWaitSemaphores = &signalsemaphores[0];

    var swapchains: [1]vk.VkSwapchainKHR = .{vkinstance.swapchain.swapchain};
    presentinfo.swapchainCount = 1;
    presentinfo.pSwapchains = &swapchains[0];
    presentinfo.pImageIndices = &imageindex;
    presentinfo.pResults = null;

    result = vk.vkQueuePresentKHR(vkinstance.logicaldevice.presentqueue.queue, &presentinfo);
    if (result == vk.VK_ERROR_OUT_OF_DATE_KHR or result != vk.VK_SUBOPTIMAL_KHR) {
        try vkinstance.recreateswapchains();
        return;
    } else if (result != vk.VK_SUCCESS or result != vk.VK_SUBOPTIMAL_KHR) {
        std.log.err("unable to obtain swapchain image present", .{});
        return;
    }
    currentframe = (currentframe + 1) % @min(vkinstance.swapchain.images.len, utilty.MAX_FRAMES_IN_FLIGHT);
}

fn updateuniformbuffer_time(frame: usize, vkinstance: *utilty.graphicalcontext) !void {
    const currenttime = vk.glfwGetTime();
    const delta: f32 = @floatCast((currenttime - vkinstance.lasttime));
    //low pass filter
    vkinstance.lastframetime = vkinstance.lastframetime + 0.01 * (delta - vkinstance.lastframetime);
    vkinstance.lasttime = currenttime;
    var ubo_time: drawing.uniformbufferobject_deltatime = undefined;
    ubo_time.deltatime = vkinstance.lastframetime;
    const ptrtime: [*]drawing.uniformbufferobject_deltatime = @ptrCast(@alignCast(vkinstance.uniformbuffermemotymapped_compute[frame]));
    ptrtime[0] = ubo_time;
}
fn updateuniformbuffer_matrix(frame: usize, vkinstance: *utilty.graphicalcontext) !void {
    var ubo_mat: drawing.uniformbufferobject_view_lookat_projection_matrix = undefined;
    ubo_mat.model = mathmatrix.rotate(
        @floatCast(std.math.degreesToRadians(@as(f32, @floatFromInt(timer.read())) / 10000000)),
        .{ 0, 1, 0 },
    );
    ubo_mat.view = mathmatrix.lookat(.{ 2, 3, 3 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    ubo_mat.projection = mathmatrix.perspective(
        std.math.degreesToRadians(45),
        @floatFromInt(vkinstance.swapchain.extent.width),
        @floatFromInt(vkinstance.swapchain.extent.height),
        0.1,
        100.0,
    );
    const ptr_mat: [*]drawing.uniformbufferobject_view_lookat_projection_matrix = @ptrCast(@alignCast(vkinstance.uniformbuffermemotymapped_3d[frame]));
    ptr_mat[0] = ubo_mat;
}
const freetype = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("freetype2/ft2build.h");
});
pub const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("GLFW/glfw3.h");
});
const mathmatrix = @import("mathmatrix.zig");
const drawing = @import("drawing.zig");
const helper = @import("helpers.zig");
const utilty = @import("utility.zig");
const main = @import("main.zig");
const std = @import("std");
