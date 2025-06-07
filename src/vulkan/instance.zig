const validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const validationlayerInstanceExtensions: [1][*c]const u8 = .{"VK_EXT_debug_utils"};
const InstanceExtensions: [0][*c]const u8 = .{};
const enablevalidationlayers: bool = true;
const validationlayerverbose: bool = false;
pub const Instance = struct {
    allocator: std.mem.Allocator,
    instance: vk.VkInstance,
    debugmessanger: vk.VkDebugUtilsMessengerEXT,
    ///create an vulkan instance
    pub fn createinstance(allocator: std.mem.Allocator) !*Instance {
        const self: *Instance = try allocator.create(Instance);
        self.allocator = allocator;

        var appinfo: vk.VkApplicationInfo = .{};
        appinfo.sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appinfo.pApplicationName = "vulkan-zig triangle example";
        appinfo.applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0);
        appinfo.pEngineName = "No Engine";
        appinfo.engineVersion = vk.VK_MAKE_VERSION(1, 0, 0);
        appinfo.apiVersion = vk.VK_API_VERSION_1_4;

        var createinfo: vk.VkInstanceCreateInfo = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createinfo.pApplicationInfo = &appinfo;

        var extensioncount: u32 = 0;
        var instanceextensions: [][*c]const u8 = undefined;
        try getrequiredextensions(self, &extensioncount, &instanceextensions);
        defer self.allocator.free(instanceextensions);
        checkextensions(self.allocator, extensioncount, &instanceextensions[0]);
        createinfo.enabledExtensionCount = extensioncount;
        createinfo.ppEnabledExtensionNames = &instanceextensions[0];

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
            return error.InstanceCreationFailed;
        }
        return self;
    }
    pub fn destroyinstance(self: *Instance) void {
        self.destroydebugmessanger();
        vk.vkDestroyInstance(self.instance, null);
        self.allocator.destroy(self);
    }
    ///creates an array of vulkan instance extensions required for instance array should be freed after use
    fn getrequiredextensions(self: *Instance, extensioncount: *u32, instanceextensions: *[][*c]const u8) !void {
        var glfwextensioncount: u32 = 0;
        const glfwextensions = vk.glfwGetRequiredInstanceExtensions(&glfwextensioncount);

        if (enablevalidationlayers) {
            extensioncount.* = glfwextensioncount + @as(u32, @intCast(validationlayerInstanceExtensions.len)) + @as(u32, @intCast(InstanceExtensions.len));
            var arr: [][*c]const u8 = try self.allocator.alloc([*c]const u8, extensioncount.*);
            var ind: usize = 0;
            for (0..glfwextensioncount) |i| {
                arr[ind] = glfwextensions[i];
                ind = ind + 1;
            }
            for (0..validationlayerInstanceExtensions.len) |i| {
                arr[ind] = validationlayerInstanceExtensions[i];
                ind = ind + 1;
            }
            for (0..InstanceExtensions.len) |i| {
                arr[ind] = InstanceExtensions[i];
                ind = ind + 1;
            }
            instanceextensions.* = arr;
        } else {
            extensioncount.* = glfwextensioncount + @as(u32, @intCast(InstanceExtensions.len));
            var arr: [][*c]const u8 = try self.allocator.alloc([*c]const u8, extensioncount.*);
            var ind: usize = 0;
            for (0..glfwextensioncount) |i| {
                arr[ind] = glfwextensions[i];
                ind = ind + 1;
            }
            for (0..InstanceExtensions.len) |i| {
                arr[ind] = InstanceExtensions[i];
                ind = ind + 1;
            }
            instanceextensions.* = arr;
        }
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
    ///setup common parameters to create debug messanger
    fn setdebugmessangercreateinfo(createinfo: *vk.VkDebugUtilsMessengerCreateInfoEXT) void {
        createinfo.sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        createinfo.messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        createinfo.messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        createinfo.pfnUserCallback = debugCallback;
        createinfo.pUserData = null;
    }
    ///create a debug messanger for vulkan validation layer
    fn createdebugmessanger(self: *Instance) !void {
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
    ///destroy the debug messanger created via createdebugmessanger
    fn destroydebugmessanger(self: *Instance) void {
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
const graphics = @import("../graphics.zig");
const main = @import("../main.zig");
const std = @import("std");
