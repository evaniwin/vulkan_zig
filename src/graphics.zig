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
    vkinstance.deinit();
    while (main.running) {

        //poll events
        vk.glfwPollEvents();
        windowhandler(window);
        viewportsizeupdate(window);
    }
}

const freetype = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("freetype2/ft2build.h");
});
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("GLFW/glfw3.h");
});
const helper = @import("helpers.zig");
const utilty = @import("utility.zig");
const main = @import("main.zig");
const std = @import("std");
