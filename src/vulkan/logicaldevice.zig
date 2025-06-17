pub const logicaldeviccecreateinfo = struct {
    allocator: std.mem.Allocator,
    deviceextensions: [][*c]const u8,
    queuelist: *graphicsqueue,
    surface: vk.VkSurfaceKHR,
    physicaldevice: *vkinstance.PhysicalDevice,
    enablevalidationlayers: bool,
    validationlayers: [][*c]const u8,
};
const queuestr = struct {
    queue: vk.VkQueue,
    familyindex: u32,
};
pub const LogicalDevice = struct {
    allocator: std.mem.Allocator,
    device: vk.VkDevice,
    physicaldevice: *vkinstance.PhysicalDevice,
    queuelist: *graphicsqueue,
    graphicsqueue: queuestr,
    presentqueue: queuestr,
    computequeue: queuestr,
    pub fn createlogicaldevice(logicaldeviceparams: logicaldeviccecreateinfo) !*LogicalDevice {
        const self: *LogicalDevice = try logicaldeviceparams.allocator.create(LogicalDevice);
        self.allocator = logicaldeviceparams.allocator;
        self.physicaldevice = logicaldeviceparams.physicaldevice;
        self.queuelist = logicaldeviceparams.queuelist;

        var quefamilyindex: [2]u32 = undefined;
        self.queuelist.queueflagsmatch(vk.VK_QUEUE_GRAPHICS_BIT | vk.VK_QUEUE_COMPUTE_BIT);
        self.queuelist.filternotinuse();
        if (self.queuelist.queuesfound == 0) @panic("no graphics & compute queue found");
        self.queuelist.markQueueInuse(self.queuelist.searchresult[0]);
        quefamilyindex[0] = self.queuelist.searchresult[0];
        self.queuelist.checkpresentCapable(logicaldeviceparams.surface, self.physicaldevice.physicaldevice);
        self.queuelist.filternotinuse();
        if (self.queuelist.queuesfound == 0) @panic("no present queue found");
        quefamilyindex[1] = self.queuelist.searchresult[0];

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
        physicaldevicefeatures.samplerAnisotropy = self.physicaldevice.physicaldevicefeatures.samplerAnisotropy;
        physicaldevicefeatures.sampleRateShading = self.physicaldevice.physicaldevicefeatures.sampleRateShading;
        //creating logicaldevice
        var createinfo: vk.VkDeviceCreateInfo = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        createinfo.pQueueCreateInfos = &quecreateinfos[0];
        createinfo.queueCreateInfoCount = quecreateinfos.len;
        createinfo.pEnabledFeatures = &physicaldevicefeatures;
        createinfo.enabledExtensionCount = @intCast(logicaldeviceparams.deviceextensions.len);
        createinfo.ppEnabledExtensionNames = @as([*c]const [*c]const u8, &logicaldeviceparams.deviceextensions[0]);

        if (logicaldeviceparams.enablevalidationlayers) {
            createinfo.enabledLayerCount = @intCast(logicaldeviceparams.validationlayers.len);
            createinfo.ppEnabledLayerNames = @as([*c]const [*c]const u8, &logicaldeviceparams.validationlayers[0]);
        } else {
            createinfo.enabledLayerCount = 0;
        }
        if (vk.vkCreateDevice(self.physicaldevice.physicaldevice, &createinfo, null, &self.device) != vk.VK_SUCCESS) {
            std.log.err("unable to create logical device", .{});
            return error.FailedLogicalDeviceCreation;
        }
        vk.vkGetDeviceQueue(self.device, quefamilyindex[0], 0, &self.graphicsqueue.queue);
        self.graphicsqueue.familyindex = quefamilyindex[0];
        vk.vkGetDeviceQueue(self.device, quefamilyindex[0], 0, &self.computequeue.queue);
        self.computequeue.familyindex = quefamilyindex[0];
        vk.vkGetDeviceQueue(self.device, quefamilyindex[1], 0, &self.presentqueue.queue);
        self.presentqueue.familyindex = quefamilyindex[1];

        return self;
    }
    pub fn destroylogicaldevice(self: *LogicalDevice) void {
        vk.vkDestroyDevice(self.device, null);
        self.allocator.destroy(self);
    }
};

pub const graphicsqueue = struct {
    allocator: std.mem.Allocator,
    availablequeues: u32,
    queues: []vk.VkQueueFamilyProperties,
    inUseQueue: []bool,
    queuesfound: u32,
    searchresult: []u32,

    pub fn getqueuefamily(allocator: std.mem.Allocator, device: vk.VkPhysicalDevice) !*graphicsqueue {
        var self: *graphicsqueue = try allocator.create(graphicsqueue);
        self.allocator = allocator;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &self.availablequeues, null);
        self.queues = try allocator.alloc(vk.VkQueueFamilyProperties, self.availablequeues);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &self.availablequeues, self.queues.ptr);
        self.searchresult = try allocator.alloc(u32, self.availablequeues);
        self.inUseQueue = try allocator.alloc(bool, self.availablequeues);
        //set all value to false
        for (0..self.availablequeues) |i| {
            self.inUseQueue[i] = false;
        }
        return self;
    }
    pub fn deinit(self: *graphicsqueue) void {
        self.allocator.free(self.inUseQueue);
        self.allocator.free(self.searchresult);
        self.allocator.free(self.queues);
        self.allocator.destroy(self);
    }
    pub fn queueflagsmatch(self: *graphicsqueue, queueFlags: vk.VkQueueFlags) void {
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            if ((self.queues[i].queueFlags & queueFlags) == queueFlags) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn queueflagsmatchexact(self: *graphicsqueue, queueFlags: vk.VkQueueFlags) void {
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            if (self.queues[i].queueFlags == queueFlags) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn checkpresentCapable(self: *graphicsqueue, surface: vk.VkSurfaceKHR, physicaldevice: vk.VkPhysicalDevice) void {
        var presentsupport: vk.VkBool32 = vk.VK_FALSE;
        var curind: u32 = 0;
        for (0..self.queues.len) |i| {
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(
                physicaldevice,
                @intCast(i),
                surface,
                &presentsupport,
            );
            if (presentsupport == vk.VK_TRUE) {
                self.searchresult[curind] = @intCast(i);
                curind = curind + 1;
            }
        }
        self.queuesfound = curind;
    }
    pub fn filternotinuse(self: *graphicsqueue) void {
        var found: u32 = 0;
        for (0..self.queuesfound) |i| {
            if (!self.inUseQueue[self.searchresult[i]]) {
                self.searchresult[found] = self.searchresult[i];
                found = found + 1;
            }
        }
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

pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vkinstance = @import("instance.zig");
const std = @import("std");
