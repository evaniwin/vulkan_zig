const validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const enablevalidationlayers: bool = true;

pub const graphicalcontext = struct {
    allocator: std.mem.Allocator,
    instance: vk.VkInstance,
    pub fn init(allocator: std.mem.Allocator) !*graphicalcontext {
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
        const extensions: helper.extensionarray = getrequiredextensions(allocator, &extensioncount);
        defer extensions.free();

        checkextensions(allocator, extensioncount, extensions);
        createinfo.enabledExtensionCount = extensioncount;
        createinfo.ppEnabledExtensionNames = extensions.extensions();

        if (!(checkvalidationlayersupport(allocator) and enablevalidationlayers)) {
            @panic("unable to find validation layers");
        }
        if (enablevalidationlayers) {
            createinfo.enabledLayerCount = @intCast(validationlayers.len);
            createinfo.ppEnabledLayerNames = &validationlayers[0];
        } else {
            createinfo.enabledLayerCount = 0;
        }

        const self: *graphicalcontext = allocator.create(graphicalcontext) catch |err| {
            std.log.err("Unable to allocate memory for vulkan instance: {s}", .{@errorName(err)});
            return err;
        };
        self.allocator = allocator;

        if (vk.vkCreateInstance(&createinfo, null, &self.instance) != vk.VK_SUCCESS) {
            std.log.err("error", .{});
            @panic("failed to create instance!");
        }
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        vk.vkDestroyInstance(self.instance, null);
        self.allocator.destroy(self);
    }

    fn getrequiredextensions(allocator: std.mem.Allocator, extensioncount: *u32) helper.extensionarray {
        var glfwextensioncount: u32 = 0;
        const glfwextensions = glfw.glfwGetRequiredInstanceExtensions(&glfwextensioncount);
        const extensionlist: [2]?[*c]const u8 = .{ "VK_EXT_DEBUG_UTILS_EXTENSION_NAME", null };
        if (enablevalidationlayers) {
            var arrayptrs = std.ArrayList([*c][*c]const u8).init(allocator);
            defer arrayptrs.deinit();
            extensioncount.* = glfwextensioncount + @as(u32, @intCast(extensionlist.?.len - 1));
            const arr = helper.extensionarray.joinstr(allocator, extensioncount.*, &arrayptrs) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };

            return arr;
        } else {
            extensioncount.* = glfwextensioncount;
            return glfwextensions;
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

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
