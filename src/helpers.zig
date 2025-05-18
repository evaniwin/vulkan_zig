pub const cstringarray = struct {
    allocator: std.mem.Allocator,
    freelist1: [256][:0][:0]const u8,

    pub fn allocateassign(self: *cstringarray, len: usize, arrptr: *std.ArrayList([*c][*c]const u8), freeslot: usize) ![*c]const [*c]const u8 {
        var strarray = try self.allocator.allocSentinel([:0]const u8, len, "\x00");
        self.freelist1[freeslot] = strarray;

        var ind: usize = 0;
        for (arrptr.items) |arr| {
            var indstr: usize = 0;
            while (arr[indstr] != 0 and ind < len) {
                const slice: [:0]const u8 = std.mem.span(arr[indstr]);
                strarray[ind] = self.allocator.dupeZ(u8, slice) catch |err| {
                    std.log.err("Unable to create buffer to store vulkan extension name {s}", .{@errorName(err)});
                    continue;
                };

                ind = ind + 1;
                indstr = indstr + 1;
            }
        }
        return @ptrCast(strarray.ptr);
    }
    pub fn free(self: *cstringarray, freeslot: usize) void {
        var ind: usize = 0;
        while (self.freelist1[freeslot][ind] != null) {
            self.allocator.free(self.freelist1[freeslot][ind]);
            ind = ind + 1;
        }
        self.allocator.free(self.freelist1[freeslot]);
    }
};

const std = @import("std");
