const validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const enablevalidationlayers: bool = true;
const validationlayerverbose: bool = false;
pub const graphicalcontext = struct {
    allocator: std.mem.Allocator,
    instance: vk.VkInstance,
    physicaldevice: vk.VkPhysicalDevice,
    debugmessanger: vk.VkDebugUtilsMessengerEXT,
    pub fn init(allocator: std.mem.Allocator) !*graphicalcontext {
        //allocate an instance of this struct
        const self: *graphicalcontext = allocator.create(graphicalcontext) catch |err| {
            std.log.err("Unable to allocate memory for vulkan instance: {s}", .{@errorName(err)});
            return err;
        };
        self.allocator = allocator;
        errdefer deinit(self);
        //create an vulkan instance
        createinstance(self);
        //setup debug messanger for vulkan validation layer
        try createdebugmessanger(self);
        try pickphysicaldevice(self);
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        destroydebugmessanger(self);
        vk.vkDestroyInstance(self.instance, null);
        self.allocator.destroy(self);
    }
    fn pickphysicaldevice(self: *graphicalcontext) !void {
        var devicecount: u32 = 0;
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &devicecount, null);
        if (devicecount == 0) {
            std.log.err("unable to find gpu with vulkan support", .{});
            return error.UnableToFindGPU;
        }
        const devicelist = self.allocator.alloc(vk.VkPhysicalDevice, devicecount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan device list {s}", .{@errorName(err)});
            return err;
        };
        defer self.allocator.free(devicelist);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &devicecount, &devicelist[0]);

        const devicescorelist = self.allocator.alloc(u32, devicecount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan device score list {s}", .{@errorName(err)});
            return err;
        };
        defer self.allocator.free(devicescorelist);

        self.physicaldevice = null;
        for (0..devicecount) |i| {
            devicescorelist[i] = try ratedevicecompatability(self, devicelist[i]);
        }
        //find best device based on score
        var topscore: u32 = 0;
        var topdevice: usize = 0;
        for (0..devicecount) |i| {
            if (topscore < devicescorelist[i]) {
                topscore = devicescorelist[i];
                topdevice = @intCast(i);
            }
        }
        if (topscore > 0) {
            self.physicaldevice = devicelist[topdevice];
        }
        if (self.physicaldevice == null) {
            std.log.err("Unable to find suitable Gpu", .{});
            return error.UnableToFIndSuitableGPU;
        }
    }
    fn getqueuefamily(self: *graphicalcontext, device: vk.VkPhysicalDevice, queueflagbits: u32, exactmatch: bool) !?u32 {
        var found: bool = false;
        var queuefamilycount: u32 = 0;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queuefamilycount, null);
        const queuefamilieslist = self.allocator.alloc(vk.VkQueueFamilyProperties, queuefamilycount) catch |err| {
            std.log.err("Unable to allocate memory for vulkan device list {s}", .{@errorName(err)});
            return err;
        };
        defer self.allocator.free(queuefamilieslist);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queuefamilycount, queuefamilieslist.ptr);
        for (0..queuefamilycount) |i| {
            if (exactmatch) {
                if (queuefamilieslist[i].queueFlags == queueflagbits) {
                    found = true;
                    queuefamilycount = @intCast(i);
                }
            } else {
                if ((queuefamilieslist[i].queueFlags & queueflagbits) == queueflagbits) {
                    found = true;
                    queuefamilycount = @intCast(i);
                }
            }
        }
        if (found) {
            return queuefamilycount;
        } else {
            return null;
        }
    }
    fn ratedevicecompatability(self: *graphicalcontext, device: vk.VkPhysicalDevice) !u32 {
        var deviceproperties: vk.VkPhysicalDeviceProperties = .{};
        var devicefeatures: vk.VkPhysicalDeviceFeatures = .{};
        vk.vkGetPhysicalDeviceProperties(device, &deviceproperties);
        vk.vkGetPhysicalDeviceFeatures(device, &devicefeatures);
        const quefamily = try getqueuefamily(self, device, vk.VK_QUEUE_GRAPHICS_BIT, false);
        if (quefamily != null) {
            return 1;
        }
        return 0;
    }
    ///setup common parameters to create debug messanger
    fn setdebugmessangercreateinfo(createinfo: *vk.VkDebugUtilsMessengerCreateInfoEXT) void {
        createinfo.sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        createinfo.messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        createinfo.messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        createinfo.pfnUserCallback = debugCallback;
        createinfo.pUserData = null;
    }
    ///create an vulkan instance
    fn createinstance(self: *graphicalcontext) void {
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
        var extensions: *helper.extensionarray = getrequiredextensions(self.allocator, &extensioncount);
        defer extensions.free();
        const extensions_c = extensions.extensions();
        checkextensions(self.allocator, extensioncount, extensions_c);
        createinfo.enabledExtensionCount = extensioncount;
        createinfo.ppEnabledExtensionNames = extensions_c;

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
            @panic("failed to create instance!");
        }
    }
    ///destroy the debug messanger created via createdebugmessanger
    fn destroydebugmessanger(self: *graphicalcontext) void {
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
    ///create a debug messanger for vulkan validation layer
    fn createdebugmessanger(self: *graphicalcontext) !void {
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

    fn getrequiredextensions(allocator: std.mem.Allocator, extensioncount: *u32) *helper.extensionarray {
        var glfwextensioncount: u32 = 0;
        const glfwextensions = glfw.glfwGetRequiredInstanceExtensions(&glfwextensioncount);

        var arrayptrs = std.ArrayList(helper.stringarrayc).init(allocator);
        defer arrayptrs.deinit();
        arrayptrs.append(helper.stringarrayc{ .string = @ptrCast(glfwextensions), .len = glfwextensioncount }) catch |err| {
            std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
            @panic("Memory allocation Error");
        };
        if (enablevalidationlayers) {
            var extensionlist: [2]?[*c]const u8 = .{ "VK_EXT_debug_utils", null };
            extensioncount.* = glfwextensioncount + @as(u32, @intCast(extensionlist.len - 1));
            arrayptrs.append(helper.stringarrayc{ .string = @ptrCast(&extensionlist[0]), .len = 1 }) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };
            const arr = helper.extensionarray.joinstr(
                allocator,
                extensioncount.*,
                &arrayptrs,
            ) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };

            return arr;
        } else {
            extensioncount.* = glfwextensioncount;
            const arr = helper.extensionarray.joinstr(
                allocator,
                extensioncount.*,
                &arrayptrs,
            ) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };
            return arr;
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

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
