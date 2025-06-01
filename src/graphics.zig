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
const app_name = "vulkan-zig triangle example";
pub fn draw() !void {
    std.log.info("render Thread started\n", .{});
    defer std.log.info("render Thread exited\n", .{});

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
    while (main.running) {

        //poll events
        vk.glfwPollEvents();
        try drawframe(vkinstance);
        windowhandler(window);
        viewportsizeupdate(window, vkinstance);
    }
    _ = vk.vkDeviceWaitIdle(vkinstance.device);
}
var recreateswapchain: bool = false;
const MAX_FRAMES_IN_FLIGHT: u32 = 4;
var currentframe: usize = 0;
fn drawframe(vkinstance: *utilty.graphicalcontext) !void {
    _ = vk.vkWaitForFences(
        vkinstance.device,
        1,
        &vkinstance.inflightfences[currentframe],
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );
    //TODO The vkAcquireNextImageKHR does not use swapchain image 0 after first loop
    var imageindex: u32 = undefined;
    var result = vk.vkAcquireNextImageKHR(
        vkinstance.device,
        vkinstance.swapchain,
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
    try updateuniformbuffer(currentframe, vkinstance);
    _ = vk.vkResetFences(vkinstance.device, 1, &vkinstance.inflightfences[currentframe]);
    _ = vk.vkResetCommandBuffer(vkinstance.commandbuffers[currentframe], 0);
    try vkinstance.recordcommandbuffer(vkinstance.commandbuffers[currentframe], imageindex);

    var submitinfo: vk.VkSubmitInfo = .{};
    submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;

    var waitsemaphores: [1]vk.VkSemaphore = .{vkinstance.imageavailablesephamores[currentframe]};
    var waitstages: [1]vk.VkPipelineStageFlags = .{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submitinfo.waitSemaphoreCount = 1;
    submitinfo.pWaitSemaphores = &waitsemaphores[0];
    submitinfo.pWaitDstStageMask = &waitstages[0];
    submitinfo.commandBufferCount = 1;
    submitinfo.pCommandBuffers = &vkinstance.commandbuffers[currentframe];

    var signalsemaphores: [1]vk.VkSemaphore = .{vkinstance.renderfinishedsephamores[imageindex]};
    submitinfo.signalSemaphoreCount = 1;
    submitinfo.pSignalSemaphores = &signalsemaphores[0];

    if (vk.vkQueueSubmit(vkinstance.graphicsqueue.queue, 1, &submitinfo, vkinstance.inflightfences[currentframe]) != vk.VK_SUCCESS) {
        std.log.err("Unable to Submit Queue", .{});
        return error.QueueSubmissionFailed;
    }

    var presentinfo: vk.VkPresentInfoKHR = .{};
    presentinfo.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentinfo.waitSemaphoreCount = 1;
    presentinfo.pWaitSemaphores = &signalsemaphores[0];

    var swapchains: [1]vk.VkSwapchainKHR = .{vkinstance.swapchain};
    presentinfo.swapchainCount = 1;
    presentinfo.pSwapchains = &swapchains[0];
    presentinfo.pImageIndices = &imageindex;
    presentinfo.pResults = null;

    result = vk.vkQueuePresentKHR(vkinstance.presentqueue.queue, &presentinfo);
    if (result == vk.VK_ERROR_OUT_OF_DATE_KHR or result != vk.VK_SUBOPTIMAL_KHR) {
        try vkinstance.recreateswapchains();
        return;
    } else if (result != vk.VK_SUCCESS or result != vk.VK_SUBOPTIMAL_KHR) {
        std.log.err("unable to obtain swapchain image present", .{});
        return;
    }
    currentframe = (currentframe + 1) % @min(vkinstance.swapchainimages.len, MAX_FRAMES_IN_FLIGHT);
}

fn updateuniformbuffer(frame: usize, vkinstance: *utilty.graphicalcontext) !void {
    var ubo: drawing.uniformbufferobject = undefined;
    ubo.model = mathmatrix.rotate(
        .{ .{ 1, 0, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 1 } },
        @floatCast(std.math.degreesToRadians(cursorpos[0])),
        .{ 0, 0, 1 },
    );
    ubo.view = mathmatrix.lookat(.{ 2, 2, 2 }, .{ 0, 0, 0 }, .{ 0, 0, 1 });
    ubo.projection = mathmatrix.perspective(
        std.math.degreesToRadians(45),
        @floatFromInt(vkinstance.swapchainextent.width),
        @floatFromInt(vkinstance.swapchainextent.height),
        0.1,
        10.0,
    );
    //ubo.projection = .{ .{ 1, 0, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 1 } };
    const ptr: [*]drawing.uniformbufferobject = @ptrCast(@alignCast(vkinstance.uniformbuffermemotymapped[frame]));
    ptr[0] = ubo;
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
