pub const obj = struct {
    allocator: std.mem.Allocator,
    vertices: []vertex,
    verticesnum: u64,
    texcoords: []texcoord,
    texcoordsnum: u32,
    faces: []face,
    facesnum: u32,

    pub fn init(allocator: std.mem.Allocator, filename: []const u8) !*obj {
        const self = try allocator.create(obj);
        self.allocator = allocator;
        const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only, .lock = .shared });
        defer file.close();
        //count data and allocate memory
        try self.countdata(file);
        self.vertices = try self.allocator.alloc(vertex, self.verticesnum);
        self.texcoords = try self.allocator.alloc(texcoord, self.texcoordsnum);
        self.faces = try self.allocator.alloc(face, self.facesnum);

        try self.populatedata(file);
        //for (0..self.verticesnum / 4) |i| {
        //    std.log.info("{d} {d} {d}", .{ self.vertices[i].coord[0], self.vertices[i].coord[1], self.vertices[i].coord[2] });
        //}
        return self;
    }
    pub fn deinit(self: *obj) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.texcoords);
        self.allocator.free(self.faces);
        self.allocator.destroy(self);
    }
    fn populatedata(self: *obj, file: std.fs.File) !void {
        try file.seekTo(0);
        var buffer: [1024]u8 = undefined;
        var readerbuf = std.io.bufferedReader(file.reader());
        const reader = readerbuf.reader();
        var ind: [3]u32 = .{ 0, 0, 0 };
        while (true) {
            const line = reader.readUntilDelimiter(&buffer, '\n') catch |err| switch (err) {
                error.EndOfStream => break,
                error.StreamTooLong => {
                    try longlinehandler(self, file, &buffer, &ind);
                    continue;
                },
                else => return err,
            };
            try self.parse(line, &ind);
        }
    }
    fn longlinehandler(self: *obj, file: std.fs.File, partbuf: []u8, ind: []u32) !void {
        _ = self;
        _ = file;
        _ = partbuf;
        _ = ind;
    }
    fn parse(self: *obj, line: []u8, ind: []u32) !void {
        var itr = std.mem.tokenizeScalar(u8, line, ' ');
        const first = itr.next().?;
        if (std.mem.eql(u8, first, "v")) {
            self.vertices[ind[0]].coord = .{
                try std.fmt.parseFloat(f32, itr.next().?),
                try std.fmt.parseFloat(f32, itr.next().?),
                try std.fmt.parseFloat(f32, itr.next().?),
            };
            ind[0] = ind[0] + 1;
            if (itr.next() != null) {
                std.log.err("Multi dimensional vertices (not 3d) detected parsing terminated : (not supported)", .{});
                return error.ParsingFailed;
            }
        } else if (std.mem.eql(u8, first, "vt")) {
            self.texcoords[ind[1]].coord = .{
                try std.fmt.parseFloat(f32, itr.next().?),
                try std.fmt.parseFloat(f32, itr.next().?),
            };
            ind[1] = ind[1] + 1;
            if (itr.next() != null) {
                std.log.err("Multi dimensional texture coordinates (not 2d) detected parsing terminated : (not supported)", .{});
                return error.ParsingFailed;
            }
        } else if (std.mem.eql(u8, first, "f")) {
            var vert = std.mem.tokenizeScalar(u8, itr.next().?, '/');
            self.faces[ind[2]].vert = .{ try std.fmt.parseUnsigned(u32, vert.next().?, 10), try std.fmt.parseUnsigned(u32, vert.next().?, 10), try std.fmt.parseUnsigned(u32, vert.next().?, 10) };
            var tex = std.mem.tokenizeScalar(u8, itr.next().?, '/');
            self.faces[ind[2]].tex = .{ try std.fmt.parseUnsigned(u32, tex.next().?, 10), try std.fmt.parseUnsigned(u32, tex.next().?, 10), try std.fmt.parseUnsigned(u32, tex.next().?, 10) };
            var nom = std.mem.tokenizeScalar(u8, itr.next().?, '/');
            self.faces[ind[2]].norm = .{ try std.fmt.parseUnsigned(u32, nom.next().?, 10), try std.fmt.parseUnsigned(u32, nom.next().?, 10), try std.fmt.parseUnsigned(u32, nom.next().?, 10) };
            ind[2] = ind[2] + 1;
            if (itr.next() != null) {
                std.log.err("Non triangle face detected parsing terminated : (not supported)", .{});
                return error.ParsingFailed;
            }
        }
    }
    fn longlinehandlercount(self: *obj, file: std.fs.File, partbuf: []u8) !void {
        _ = self;
        _ = file;
        _ = partbuf;
    }
    fn countdata(self: *obj, file: std.fs.File) !void {
        var buffer: [1024]u8 = undefined;
        var readerbuf = std.io.bufferedReader(file.reader());
        const reader = readerbuf.reader();
        self.verticesnum = 0;
        self.texcoordsnum = 0;
        self.facesnum = 0;
        while (true) {
            const line = reader.readUntilDelimiter(&buffer, '\n') catch |err| switch (err) {
                error.EndOfStream => break,
                error.StreamTooLong => {
                    try longlinehandlercount(self, file, &buffer);
                    continue;
                },
                else => return err,
            };
            if (std.mem.startsWith(u8, line, "v ")) {
                self.verticesnum = self.verticesnum + 1;
            } else if (std.mem.startsWith(u8, line, "vt ")) {
                self.texcoordsnum = self.texcoordsnum + 1;
            } else if (std.mem.startsWith(u8, line, "f ")) {
                self.facesnum = self.facesnum + 1;
            }
        }
    }
};

const vertex = struct { coord: [3]f32 };
const texcoord = struct { coord: [2]f32 };
const face = struct {
    vert: [3]u32,
    tex: [3]u32,
    norm: [3]u32,
};
const std = @import("std");
