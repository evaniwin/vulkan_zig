pub const swapchaincreateinfo = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    physicaldevice: vk.VkPhysicalDevice,
    surface: vk.VkSurfaceKHR,
    oldswapchain: vk.VkSwapchainKHR,
    window: *vk.GLFWwindow,
};
/// A swapchain is unique to a single surface and cannot be shared across multiple surfaces
/// A swapchain is also bound to a logical device and cannot be shared
pub const swapchain = struct {
    allocator: std.mem.Allocator,
    logicaldevice: *vklogicaldevice.LogicalDevice,
    surface: vk.VkSurfaceKHR,
    swapchain: vk.VkSwapchainKHR,
    imageformat: vk.VkFormat,
    extent: vk.VkExtent2D,
    images: []vk.VkImage,
    pub fn createswapchain(swapchaincreateparams: swapchaincreateinfo) !*swapchain {
        const self: *swapchain = try swapchaincreateparams.allocator.create(swapchain);
        self.allocator = swapchaincreateparams.allocator;
        self.logicaldevice = swapchaincreateparams.logicaldevice;
        self.surface = swapchaincreateparams.surface;

        const swapchainsprt: *swapchainsupport = try swapchainsupport.getSwapchainDetails(
            self.allocator,
            self.surface,
            swapchaincreateparams.physicaldevice,
        );
        defer swapchainsprt.deinit();
        const surfaceformat: vk.VkSurfaceFormatKHR = try swapchainsprt.chooseformat();
        self.imageformat = surfaceformat.format;
        const presentmode: vk.VkPresentModeKHR = swapchainsprt.choosepresentmode();
        const extent: vk.VkExtent2D = swapchainsprt.chooseswapextent(swapchaincreateparams.window);
        self.extent = extent;
        var imagecount: u32 = swapchainsprt.capabilities.minImageCount + 1;
        if (swapchainsprt.capabilities.maxImageCount > 0 and imagecount > swapchainsprt.capabilities.maxImageCount) {
            imagecount = swapchainsprt.capabilities.maxImageCount;
        }

        var createinfo: vk.VkSwapchainCreateInfoKHR = .{};
        createinfo.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        createinfo.surface = self.surface;

        createinfo.minImageCount = imagecount;
        createinfo.imageFormat = surfaceformat.format;
        createinfo.imageColorSpace = surfaceformat.colorSpace;
        createinfo.imageExtent = extent;
        createinfo.imageArrayLayers = 1;
        createinfo.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        if (self.logicaldevice.presentqueue.familyindex != self.logicaldevice.graphicsqueue.familyindex) {
            const queuefamilyindices: [2]u32 = .{ self.logicaldevice.presentqueue.familyindex, self.logicaldevice.graphicsqueue.familyindex };
            createinfo.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
            createinfo.queueFamilyIndexCount = 2;
            createinfo.pQueueFamilyIndices = &queuefamilyindices[0];
        } else {
            //use this if graphics que and present que are same
            createinfo.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
            createinfo.queueFamilyIndexCount = 0;
            createinfo.pQueueFamilyIndices = null;
        }

        createinfo.preTransform = swapchainsprt.capabilities.currentTransform;
        createinfo.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

        createinfo.presentMode = presentmode;
        createinfo.clipped = vk.VK_TRUE;

        createinfo.oldSwapchain = swapchaincreateparams.oldswapchain;
        if (vk.vkCreateSwapchainKHR(self.logicaldevice.device, &createinfo, null, &self.swapchain) != vk.VK_SUCCESS) {
            std.log.err("Unable to Create Swapchain", .{});
            return error.SwapChainCreationFailed;
        }
        try self.getswapchainImages();
        return self;
    }
    fn getswapchainImages(self: *swapchain) !void {
        var imagecount: u32 = 0;
        _ = vk.vkGetSwapchainImagesKHR(self.logicaldevice.device, self.swapchain, &imagecount, null);
        self.images = try self.allocator.alloc(vk.VkImage, imagecount);
        _ = vk.vkGetSwapchainImagesKHR(self.logicaldevice.device, self.swapchain, &imagecount, &self.images[0]);
    }
    fn destroyswapchainimages(self: *swapchain) void {
        self.allocator.free(self.images);
    }
    pub fn freeswapchain(self: *swapchain) void {
        vk.vkDestroySwapchainKHR(self.logicaldevice.device, self.swapchain, null);
        self.destroyswapchainimages();
        self.allocator.destroy(self);
    }
};

pub const swapchainsupport = struct {
    allocator: std.mem.Allocator,
    capabilities: vk.VkSurfaceCapabilitiesKHR,
    formatcount: u32,
    formats: []vk.VkSurfaceFormatKHR,
    presentmodecount: u32,
    presentmode: []vk.VkPresentModeKHR,

    pub fn getSwapchainDetails(allocator: std.mem.Allocator, surface: vk.VkSurfaceKHR, device: vk.VkPhysicalDevice) !*swapchainsupport {
        var self: *swapchainsupport = try allocator.create(swapchainsupport);
        self.allocator = allocator;

        _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &self.capabilities);
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &self.formatcount, null);
        self.formats = try allocator.alloc(vk.VkSurfaceFormatKHR, @max(self.formatcount, 1));
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &self.formatcount, &self.formats[0]);
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &self.presentmodecount, null);
        self.presentmode = try allocator.alloc(vk.VkPresentModeKHR, @max(self.presentmodecount, 1));
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &self.presentmodecount, &self.presentmode[0]);
        return self;
    }
    pub fn deinit(self: *swapchainsupport) void {
        self.allocator.free(self.formats);
        self.allocator.free(self.presentmode);
        self.allocator.destroy(self);
    }
    pub fn chooseformat(self: *swapchainsupport) !vk.VkSurfaceFormatKHR {
        for (0..self.formatcount) |i| {
            if (self.formats[i].colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR and self.formats[i].format == vk.VK_FORMAT_B8G8R8A8_SRGB) {
                return self.formats[i];
            }
        }
        return error.UnableTOFindFormats;
    }
    pub fn choosepresentmode(self: *swapchainsupport) vk.VkPresentModeKHR {
        for (0..self.presentmodecount) |i| {
            if (self.presentmode[i] == vk.VK_PRESENT_MODE_MAILBOX_KHR) {
                return self.presentmode[i];
            }
        }
        return vk.VK_PRESENT_MODE_FIFO_KHR;
    }
    pub fn chooseswapextent(self: *swapchainsupport, window: *vk.GLFWwindow) vk.VkExtent2D {
        if (self.capabilities.currentExtent.width != std.math.maxInt(u32)) {
            return self.capabilities.currentExtent;
        }
        var glfwsize: [2]c_int = undefined;
        vk.glfwGetFramebufferSize(window, &glfwsize[0], &glfwsize[1]);
        var actualextent: vk.VkExtent2D = .{ .width = @intCast(glfwsize[0]), .height = @intCast(glfwsize[1]) };
        actualextent.width = std.math.clamp(actualextent.width, self.capabilities.minImageExtent.width, self.capabilities.maxImageExtent.width);
        actualextent.height = std.math.clamp(actualextent.height, self.capabilities.minImageExtent.height, self.capabilities.maxImageExtent.height);
        return actualextent;
    }
};
pub const vk = graphics.vk;
const graphics = @import("../graphics.zig");
const vklogicaldevice = @import("logicaldevice.zig");
const std = @import("std");
