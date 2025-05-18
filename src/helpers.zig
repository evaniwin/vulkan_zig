pub const extensionarray = struct {
    allocator: std.mem.Allocator,
    extensioncount: u32,
    array: std.ArrayList(?[*c]const u8),
    pub fn joinstr(allocator: std.mem.Allocator, extensioncount: u32, arrayptrlist: *std.ArrayList(stringarrayc)) !*extensionarray {
        const self = try allocator.create(extensionarray);
        self.allocator = allocator;
        self.extensioncount = extensioncount;
        self.array = std.ArrayList(?[*c]const u8).init(allocator);
        for (arrayptrlist.items) |itm| {
            var i: usize = 0;
            while ((itm.string[i] != null) and (itm.len < i)) {
                try self.array.append(itm.string[i]);
                i = i + 1;
            }
        }
        try self.array.append(null);
        return self;
    }
    pub fn extensions(self: *extensionarray) [*c]const [*c]const u8 {
        return @ptrCast(self.array.items.ptr);
    }
    pub fn free(self: *extensionarray) void {
        self.array.deinit();
        self.allocator.destroy(self);
    }
};
pub const stringarrayc = struct {
    string: [*c][*c]const u8,
    len: u32,
};
const std = @import("std");
