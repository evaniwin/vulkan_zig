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

fn cursorposcallback(_: ?*vk.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    std.debug.print("x:{d} y:{d}\n", .{ xpos, ypos });
}

fn errorcallback(err: c_int, decsription: [*c]const u8) callconv(.c) void {
    std.log.err("glfw error code{d}--{any}", .{ err, decsription });
}
fn windowhandler(window: ?*vk.GLFWwindow) void {
    if (vk.glfwWindowShouldClose(window) != 0) {
        std.log.warn("stop condition", .{});
        main.running = false;
    }
}
fn viewportsizeupdate(window: ?*vk.GLFWwindow) void {
    //opengl viewport update
    var framebuffer: [2]c_int = undefined;
    vk.glfwGetFramebufferSize(window, &framebuffer[0], &framebuffer[1]);
    //do something
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
    vk.glfwWindowHint(vk.GLFW_RESIZABLE, vk.GLFW_FALSE);
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
        viewportsizeupdate(window);
    }
    _ = vk.vkDeviceWaitIdle(vkinstance.device);
}

fn drawframe(vkinstance: *utilty.graphicalcontext) !void {
    _ = vk.vkWaitForFences(vkinstance.device, 1, &vkinstance.inflightfence[0], vk.VK_TRUE, std.math.maxInt(u64));
    _ = vk.vkResetFences(vkinstance.device, 1, &vkinstance.inflightfence[0]);

    var imageindex: u32 = undefined;
    _ = vk.vkAcquireNextImageKHR(
        vkinstance.device,
        vkinstance.swapchain,
        std.math.maxInt(u64),
        vkinstance.imageavailablesephamore[0],
        null,
        &imageindex,
    );

    _ = vk.vkResetCommandBuffer(vkinstance.commandbuffer, 0);
    try vkinstance.recordcommandbuffer(vkinstance.commandbuffer, imageindex);

    var submitinfo: vk.VkSubmitInfo = .{};
    submitinfo.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;

    var waitsemaphores: [1]vk.VkSemaphore = .{vkinstance.imageavailablesephamore[0]};
    var waitstages: [1]vk.VkPipelineStageFlags = .{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submitinfo.waitSemaphoreCount = 1;
    submitinfo.pWaitSemaphores = &waitsemaphores[0];
    submitinfo.pWaitDstStageMask = &waitstages[0];
    submitinfo.commandBufferCount = 1;
    submitinfo.pCommandBuffers = &vkinstance.commandbuffer;

    var signalsemaphores: [1]vk.VkSemaphore = .{vkinstance.renderfinishedsephamore[0]};
    submitinfo.signalSemaphoreCount = 1;
    submitinfo.pSignalSemaphores = &signalsemaphores[0];

    if (vk.vkQueueSubmit(vkinstance.graphicsqueue.queue, 1, &submitinfo, vkinstance.inflightfence[0]) != vk.VK_SUCCESS) {
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

    _ = vk.vkQueuePresentKHR(vkinstance.presentqueue.queue, &presentinfo);
}
const freetype = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("freetype2/ft2build.h");
});
pub const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("GLFW/glfw3.h");
});
const helper = @import("helpers.zig");
const utilty = @import("utility.zig");
const main = @import("main.zig");
const std = @import("std");
