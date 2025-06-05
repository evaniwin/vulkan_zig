pub const obj = struct {
    allocator: std.mem.Allocator,
    vertices: []vertex,
    verticesnum: u64,
    texcoords: []texcoord,
    texcoordsnum: u32,
    faces: []face,
    facesnum: u32,
    vdata: []drawing.data,
    idata: []u32,
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

        return self;
    }
    pub fn deinit(self: *obj) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.texcoords);
        self.allocator.free(self.faces);
        self.allocator.destroy(self);
    }
    pub fn processformatdata(self: *obj) !void {
        const data: [][2]u32 = try self.allocator.alloc([2]u32, self.facesnum * 3);
        defer self.allocator.free(data);
        var dataind: u32 = 0;
        const ind: []u32 = try self.allocator.alloc(u32, self.facesnum * 3);
        defer self.allocator.free(ind);
        var indx: u32 = 0;
        //perform vertex buffer de duplication
        for (0..self.faces.len) |i| {
            for (0..3) |j| {
                var matchfound = false;
                for (((i * 3) + j)..0) |k| {
                    //check if there are already existing entries
                    if (data[k][0] == self.faces[i].vert[j]) {
                        if (data[k][1] == self.faces[i].tex[j]) {
                            matchfound = true;
                            ind[indx] = k;
                            indx = indx + 1;
                            break;
                        }
                    }
                }
                if (!matchfound) {
                    //if no match is found create new entry
                    data[dataind] = .{ self.faces[i].vert[j], self.faces[i].tex[j] };
                    dataind = dataind + 1;
                    ind[indx] = (i * 3) + j;
                    indx = indx + 1;
                }
            }
        }
        self.formatdata(data, ind);
    }
    fn formatdata(self: *obj, data: [][2]u32, ind: []u32) !void {
        self.vdata = try self.allocator.alloc(drawing.data, data.len);
        self.idata = try self.allocator.alloc(u32, ind.len);
        for (0..data.len) |i| {
            self.idata[i] = .{
                .vertex = .{
                    self.vertices[data[i][0]].coord[0],
                    self.vertices[data[i][0]].coord[1],
                    self.vertices[data[i][0]].coord[2],
                },
                .color = .{ 0, 0, 0 },
                .texcoord = .{
                    self.texcoords[data[i][1]].coord[0],
                    self.texcoords[data[i][1]].coord[0],
                },
            };
        }
        for (0..ind.len) |i| {
            self.idata[i] = ind[i];
        }
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
                error.StreamTooLong => blk: {
                    try reader.skipUntilDelimiterOrEof('\n');
                    break :blk buffer[0..buffer.len];
                },
                else => return err,
            };
            try self.parse(line, &ind);
        }
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
            const ovrflow = itr.next();
            if (ovrflow != null and ovrflow.?[0] != '#') {
                std.log.err("Multi dimensional vertices (not 3d) detected parsing terminated : (not supported)", .{});
                return error.ParsingFailed;
            }
        } else if (std.mem.eql(u8, first, "vt")) {
            self.texcoords[ind[1]].coord = .{
                try std.fmt.parseFloat(f32, itr.next().?),
                try std.fmt.parseFloat(f32, itr.next().?),
            };
            ind[1] = ind[1] + 1;
            const ovrflow = itr.next();
            if (ovrflow != null and ovrflow.?[0] != '#') {
                std.log.err("Multi dimensional texture coordinates (not 2d) detected parsing terminated : (not supported)", .{});
                return error.ParsingFailed;
            }
        } else if (std.mem.eql(u8, first, "f")) {
            var a = std.mem.tokenizeScalar(u8, itr.next().?, '/');
            var b = std.mem.tokenizeScalar(u8, itr.next().?, '/');
            var c = std.mem.tokenizeScalar(u8, itr.next().?, '/');

            self.faces[ind[2]].vert = .{
                try std.fmt.parseUnsigned(u32, a.next().?, 10) - 1,
                try std.fmt.parseUnsigned(u32, b.next().?, 10) - 1,
                try std.fmt.parseUnsigned(u32, c.next().?, 10) - 1,
            };
            self.faces[ind[2]].tex = .{
                try std.fmt.parseUnsigned(u32, a.next().?, 10) - 1,
                try std.fmt.parseUnsigned(u32, b.next().?, 10) - 1,
                try std.fmt.parseUnsigned(u32, c.next().?, 10) - 1,
            };
            self.faces[ind[2]].norm = .{
                try std.fmt.parseUnsigned(u32, a.next().?, 10) - 1,
                try std.fmt.parseUnsigned(u32, b.next().?, 10) - 1,
                try std.fmt.parseUnsigned(u32, c.next().?, 10) - 1,
            };
            ind[2] = ind[2] + 1;
            const ovrflow = itr.next();
            if (ovrflow != null and ovrflow.?[0] != '#') {
                std.log.err("Non triangle face detected parsing terminated : (not supported)", .{});
                return error.ParsingFailed;
            }
        }
    }

    fn countdata(self: *obj, file: std.fs.File) !void {
        var buffer: [1024]u8 = undefined;
        var readerbuf = std.io.bufferedReader(file.reader());
        const reader = readerbuf.reader();
        self.verticesnum = 0;
        self.texcoordsnum = 0;
        self.facesnum = 0;
        while (true) {
            const line: []u8 = reader.readUntilDelimiter(&buffer, '\n') catch |err| switch (err) {
                error.EndOfStream => break,
                error.StreamTooLong => blk: {
                    try reader.skipUntilDelimiterOrEof('\n');
                    break :blk buffer[0..buffer.len];
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
const drawing = @import("drawing.zig");
const std = @import("std");
