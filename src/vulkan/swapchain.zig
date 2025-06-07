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
const std = @import("std");
