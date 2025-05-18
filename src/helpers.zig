pub const extensionarray = struct {
    allocator: std.mem.Allocator,
    extensioncount: u8,
    array: std.ArrayList([*c][*c]const u8),
    pub fn joinstr(allocator: std.mem.Allocator, extensioncount: u8, arrayptrlist: *std.ArrayList([*c][*c]const u8)) !*extensionarray {
        const self = try allocator.create(extensionarray);
        self.allocator = allocator;
        self.extensioncount = extensioncount;
        self.array = std.ArrayList([*c][*c]const u8).init(allocator);
        _ = arrayptrlist.items;
        return self;
    }
    pub fn extensions(self: *extensionarray) [*c]const [*c]const u8 {
        return @ptrCast(self.array.items.ptr);
    }
    pub fn free(self: *extensionarray) void {
        self.array.deinit();
        self.allocator.free(self);
    }
};

const std = @import("std");
