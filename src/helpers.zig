pub const extensionarray = struct {
    allocator: std.mem.Allocator,
    extensioncount: u32,
    array: []?*const u8,
    pub fn joinstr(allocator: std.mem.Allocator, extensioncount: u32, arrayptrlist: *std.ArrayList(stringarrayc)) !*extensionarray {
        const self = try allocator.create(extensionarray);
        self.allocator = allocator;
        self.extensioncount = extensioncount;
        self.array = try allocator.alloc(?*const u8, extensioncount + 1);
        var count: u32 = 0;
        for (arrayptrlist.items) |itm| {
            var i: usize = 0;
            while ((itm.string[i] != null) and (itm.len > i)) {
                self.array[count] = itm.string[i];
                i = i + 1;
                count = count + 1;
            }
        }
        self.array[extensioncount] = null;
        return self;
    }
    pub fn extensions(self: *extensionarray) [*c]const [*c]const u8 {
        return @ptrCast(self.array.ptr);
    }
    pub fn free(self: *extensionarray) void {
        self.allocator.free(self.array);
        self.allocator.destroy(self);
    }
};
pub const stringarrayc = struct {
    string: [*c][*c]const u8,
    len: u32,
};
const std = @import("std");
