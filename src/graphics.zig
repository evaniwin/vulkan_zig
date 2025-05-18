fn keycallback(_: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = scancode;
    _ = mods;
    if ((key == glfw.GLFW_KEY_ESCAPE) and (action == glfw.GLFW_PRESS)) {
        main.running = false;
    }

    if (action == glfw.GLFW_PRESS or action == glfw.GLFW_REPEAT) {
        if ((key == glfw.GLFW_KEY_UP)) {
            std.debug.print("up arrow key pressed\n", .{});
        }
        if ((key == glfw.GLFW_KEY_DOWN)) {
            std.debug.print("down arrow key pressed\n", .{});
        }
        if ((key == glfw.GLFW_KEY_RIGHT)) {
            std.debug.print("right arrow key pressed\n", .{});
        }
        if ((key == glfw.GLFW_KEY_LEFT)) {
            std.debug.print("left arrow key pressed\n", .{});
        }
        if (key == glfw.GLFW_KEY_HOME) {
            std.debug.print("home key pressed\n", .{});
        }
        if (key == glfw.GLFW_KEY_TAB) {
            std.debug.print("tab key pressed\n", .{});
        }
    }
}

fn mousebuttoncallback(_: ?*glfw.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = mods;
    if (button == glfw.GLFW_MOUSE_BUTTON_LEFT and action == glfw.GLFW_PRESS) {
        std.debug.print("left mouse button clicked\n", .{});
    }
}

fn cursorposcallback(_: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    std.debug.print("x:{d} y:{d}\n", .{ xpos, ypos });
}

fn errorcallback(err: c_int, decsription: [*c]const u8) callconv(.c) void {
    std.log.err("glfw error code{d}--{any}", .{ err, decsription });
}
fn windowhandler(window: ?*glfw.GLFWwindow) void {
    if (glfw.glfwWindowShouldClose(window) != 0) {
        std.log.warn("stop condition", .{});
        main.running = false;
    }
}
fn viewportsizeupdate(window: ?*glfw.GLFWwindow) void {
    //opengl viewport update
    var framebuffer: [2]c_int = undefined;
    glfw.glfwGetFramebufferSize(window, &framebuffer[0], &framebuffer[1]);
    //do something
}
const app_name = "vulkan-zig triangle example";
pub fn draw() !void {
    std.log.info("render Thread started\n", .{});
    defer std.log.info("render Thread exited\n", .{});

    if (glfw.glfwInit() != glfw.GLFW_TRUE) return error.GlfwInitFailed;
    defer glfw.glfwTerminate();

    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        std.log.err("GLFW could not find libvulkan", .{});
        return error.NoVulkan;
    }

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);
    const window = glfw.glfwCreateWindow(
        @intCast(main.viewportsize[0]),
        @intCast(main.viewportsize[1]),
        app_name,
        null,
        null,
    ) orelse return error.WindowInitFailed;
    defer glfw.glfwDestroyWindow(window);

    //set various callback functions
    _ = glfw.glfwSetErrorCallback(errorcallback);
    _ = glfw.glfwSetKeyCallback(window, keycallback);
    _ = glfw.glfwSetCursorPosCallback(window, cursorposcallback);
    _ = glfw.glfwSetMouseButtonCallback(window, mousebuttoncallback);

    const vkinstance = utilty.graphicalcontext.init(main.allocator) catch |err| {
        std.log.err("Unable instance creation failed: {s}", .{@errorName(err)});
        return;
    };
    vkinstance.deinit();
    while (main.running) {

        //poll events
        glfw.glfwPollEvents();
        windowhandler(window);
        viewportsizeupdate(window);
    }
}
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const freetype = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("freetype2/ft2build.h");
});
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const helper = @import("helpers.zig");
const utilty = @import("utility.zig");
const main = @import("main.zig");
const std = @import("std");
