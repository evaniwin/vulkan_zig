const validationlayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const deviceextensions: [1][*c]const u8 = .{"VK_KHR_swapchain"};
const enablevalidationlayers: bool = true;
const validationlayerverbose: bool = false;
pub const graphicalcontext = struct {
    allocator: std.mem.Allocator,
    window: *vk.GLFWwindow,
    instance: vk.VkInstance,
    physicaldevice: vk.VkPhysicalDevice,
    device: vk.VkDevice,
    queuelist: *graphicsqueue,
    graphicsqueue: vk.VkQueue,
    presentqueue: vk.VkQueue,
    debugmessanger: vk.VkDebugUtilsMessengerEXT,
    surface: vk.VkSurfaceKHR,
    instanceextensions: *helper.extensionarray,
    pub fn init(allocator: std.mem.Allocator, window: *vk.GLFWwindow) !*graphicalcontext {
        //allocate an instance of this struct
        const self: *graphicalcontext = allocator.create(graphicalcontext) catch |err| {
            std.log.err("Unable to allocate memory for vulkan instance: {s}", .{@errorName(err)});
            return err;
        };
        self.allocator = allocator;
        self.window = window;
        errdefer deinit(self);
        //create an vulkan instance
        createinstance(self);
        //setup debug messanger for vulkan validation layer
        try createdebugmessanger(self);
        try createsurface(self);
        try pickphysicaldevice(self);
        self.queuelist = try graphicsqueue.getqueuefamily(self, self.physicaldevice);
        try createlogicaldevice(self);
        return self;
    }
    pub fn deinit(self: *graphicalcontext) void {
        self.instanceextensions.free();
        destroylogicaldevice(self);
        destroydebugmessanger(self);
        vk.vkDestroySurfaceKHR(self.instance, self.surface, null);
        vk.vkDestroyInstance(self.instance, null);
        self.queuelist.deinit();
        self.allocator.destroy(self);
    }
    fn createsurface(self: *graphicalcontext) !void {
        if (vk.glfwCreateWindowSurface(self.instance, self.window, null, &self.surface) != vk.VK_SUCCESS) {
            std.log.err("Glfw surface creation failed", .{});
            return error.GlfwSurfaceCreationFailed;
        }
    }
    fn createlogicaldevice(self: *graphicalcontext) !void {
        self.queuelist.queueflagsmatch(vk.VK_QUEUE_GRAPHICS_BIT);
        const ques1num = self.queuelist.queuesfound;
        const ques1 = try self.allocator.dupe(u32, self.queuelist.searchresult);
        defer self.allocator.free(ques1);
        self.queuelist.checkpresentCapable(self, null);
        const ques2num = self.queuelist.queuesfound;
        const ques2 = try self.allocator.dupe(u32, self.queuelist.searchresult);
        defer self.allocator.free(ques2);
        var quefamilyindex: [2]u32 = undefined;
        var uniquefound: bool = false;
        for (0..ques1num) |i| {
            for (0..ques2num) |j| {
                if (ques1[i] != ques2[j]) {
                    quefamilyindex = .{ ques1[i], ques2[j] };
                    uniquefound = true;
                }
            }
        }
        if (!uniquefound) {
            std.log.err("Unable to find unique quefamilies", .{});
            return error.UnableToFindUniqueQueueFamilyIndex;
        }
        var quecreateinfos: [quefamilyindex.len]vk.VkDeviceQueueCreateInfo = undefined;
        var quepriority: f32 = 1.0;
        for (0..quefamilyindex.len) |i| {
            quecreateinfos[i].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            quecreateinfos[i].pNext = null;
            quecreateinfos[i].flags = 0;
            quecreateinfos[i].queueFamilyIndex = quefamilyindex[i];
            quecreateinfos[i].queueCount = 1;
            quecreateinfos[i].pQueuePriorities = &quepriority;
        } //specify device features
        var physicaldevicefeatures: vk.VkPhysicalDeviceFeatures = .{};

        //creating logicaldevice
        var createinfo: vk.VkDeviceCreateInfo = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createinfo.pQueueCreateInfos = &quecreateinfos[0];
        createinfo.queueCreateInfoCount = quecreateinfos.len;
        createinfo.pEnabledFeatures = &physicaldevicefeatures;
        createinfo.enabledExtensionCount = @intCast(deviceextensions.len);
        createinfo.ppEnabledExtensionNames = @as([*c]const [*c]const u8, &deviceextensions[0]);

        if (enablevalidationlayers) {
            createinfo.enabledLayerCount = @intCast(validationlayers.len);
            createinfo.ppEnabledLayerNames = @as([*c]const [*c]const u8, &validationlayers[0]);
        } else {
            createinfo.enabledLayerCount = 0;
        }
        if (vk.vkCreateDevice(self.physicaldevice, &createinfo, null, &self.device) != vk.VK_SUCCESS) {
            std.log.err("unable to create logical device", .{});
            return error.FailedLogicalDeviceCreation;
        }
        vk.vkGetDeviceQueue(self.device, quefamilyindex[0], 0, &self.graphicsqueue);
        vk.vkGetDeviceQueue(self.device, quefamilyindex[1], 0, &self.presentqueue);
    }
    fn destroylogicaldevice(self: *graphicalcontext) void {
        vk.vkDestroyDevice(self.device, null);
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

    fn ratedevicecompatability(self: *graphicalcontext, device: vk.VkPhysicalDevice) !u32 {
        var score: u32 = 0;
        var deviceproperties: vk.VkPhysicalDeviceProperties = .{};
        var devicefeatures: vk.VkPhysicalDeviceFeatures = .{};
        vk.vkGetPhysicalDeviceProperties(device, &deviceproperties);
        vk.vkGetPhysicalDeviceFeatures(device, &devicefeatures);

        //score based on available extension

        if (try checkdeviceextensionsupport(self, device)) {
            score = score + 50;
        }

        //score based on available queue families
        const queuelist = try graphicsqueue.getqueuefamily(self, device);
        defer queuelist.deinit();
        queuelist.queueflagsmatch(vk.VK_QUEUE_GRAPHICS_BIT);
        if (queuelist.queuesfound > 0) score = score + 20;
        queuelist.queueflagsmatch(vk.VK_QUEUE_COMPUTE_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_TRANSFER_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_SPARSE_BINDING_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_PROTECTED_BIT);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_VIDEO_DECODE_BIT_KHR);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_VIDEO_ENCODE_BIT_KHR);
        if (queuelist.queuesfound > 0) score = score + 10;
        queuelist.queueflagsmatch(vk.VK_QUEUE_OPTICAL_FLOW_BIT_NV);
        if (queuelist.queuesfound > 0) score = score + 10;

        return score;
    }
    fn checkdeviceextensionsupport(self: *graphicalcontext, device: vk.VkPhysicalDevice) !bool {
        var extensioncount: u32 = 0;
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extensioncount, null);
        var extensionproperties = try self.allocator.alloc(vk.VkExtensionProperties, extensioncount);
        defer self.allocator.free(extensionproperties);
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extensioncount, &extensionproperties[0]);
        var requiredestensionsavailable: bool = false;
        var extensionsfound: u32 = 0;
        for (0..deviceextensions.len) |i| {
            requiredestensionsavailable = false;
            for (0..extensioncount) |j| {
                if (std.mem.orderZ(u8, deviceextensions[i], @ptrCast(&extensionproperties[j].extensionName)) == .eq) {
                    requiredestensionsavailable = true;
                    extensionsfound = extensionsfound + 1;
                }
            }
            if (!requiredestensionsavailable) {
                std.log.err("Unable to find Required Device Extensions: {s}", .{deviceextensions[i]});
            }
        }
        std.log.info("{d}/{d} Device Extensions found", .{ extensionsfound, deviceextensions.len });
        if (extensionsfound == deviceextensions.len) {
            return true;
        } else {
            std.log.err("Unable to find Required Device Extensions", .{});
            return error.UnableToFindRequiredDeviceExtensions;
        }
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
        try getrequiredextensions(self, &extensioncount);
        const extensions_c = self.instanceextensions.extensions();
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

    fn getrequiredextensions(self: *graphicalcontext, extensioncount: *u32) !void {
        var glfwextensioncount: u32 = 0;
        const glfwextensions = vk.glfwGetRequiredInstanceExtensions(&glfwextensioncount);

        var arrayptrs = std.ArrayList(helper.stringarrayc).init(self.allocator);
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
                self.allocator,
                extensioncount.*,
                &arrayptrs,
            ) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };

            self.instanceextensions = arr;
        } else {
            extensioncount.* = glfwextensioncount;
            const arr = helper.extensionarray.joinstr(
                self.allocator,
                extensioncount.*,
                &arrayptrs,
            ) catch |err| {
                std.log.err("Unable to allocate memory for vulkan extension array {s}", .{@errorName(err)});
                @panic("Memory allocation Error");
            };
            self.instanceextensions = arr;
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
const graphicsqueue = struct {
    allocator: std.mem.Allocator,
    availablequeues: u32,
    queues: []vk.VkQueueFamilyProperties,
    queuesfound: u32,
    searchresult: []u32,
    inUseQueue: []bool,
    pub fn getqueuefamily(graphicalcontextself: *graphicalcontext, device: vk.VkPhysicalDevice) !*graphicsqueue {
        var self: *graphicsqueue = try graphicalcontextself.allocator.create(graphicsqueue);
        self.allocator = graphicalcontextself.allocator;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &self.availablequeues, null);
        self.queues = try graphicalcontextself.allocator.alloc(vk.VkQueueFamilyProperties, self.availablequeues);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &self.availablequeues, self.queues.ptr);
        self.searchresult = try graphicalcontextself.allocator.alloc(u32, self.availablequeues);
        self.inUseQueue = try graphicalcontextself.allocator.alloc(bool, self.availablequeues);
        return self;
    }
    pub fn deinit(self: *graphicsqueue) void {
        self.allocator.free(self.inUseQueue);
        self.allocator.free(self.searchresult);
        self.allocator.free(self.queues);
        self.allocator.destroy(self);
    }
    pub fn queueflagsmatch(self: *graphicsqueue, queueFlags: u32) void {
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            if ((self.queues[i].queueFlags & queueFlags) == queueFlags) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn queueflagsmatchexact(self: *graphicsqueue, queueFlags: u32) void {
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            if (self.queues[i].queueFlags == queueFlags) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn checkpresentCapable(self: *graphicsqueue, graphicalcontextself: *graphicalcontext, physicaldevice: vk.VkPhysicalDevice) void {
        var presentsupport: vk.VkBool32 = vk.VK_FALSE;
        var curind: u32 = 0;
        var curPhysicaldevice: vk.VkPhysicalDevice = undefined;
        if (physicaldevice != null) {
            curPhysicaldevice = physicaldevice;
        } else {
            curPhysicaldevice = graphicalcontextself.physicaldevice;
        }
        for (0..self.queues.len) |i| {
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(
                curPhysicaldevice,
                @intCast(i),
                graphicalcontextself.surface,
                &presentsupport,
            );
            if (presentsupport == vk.VK_TRUE) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn checkifinuse(self: *graphicsqueue, Queue: u32) bool {
        return self.inUseQueue[Queue];
    }
    pub fn markQueueInuse(self: *graphicsqueue, Queue: u32) void {
        self.inUseQueue[Queue] = true;
    }
    pub fn unmarkQueueInuse(self: *graphicsqueue, Queue: u32) void {
        self.inUseQueue[Queue] = false;
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

const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("GLFW/glfw3.h");
});
const helper = @import("helpers.zig");
const main = @import("main.zig");
const std = @import("std");
