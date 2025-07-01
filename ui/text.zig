const std = @import("std");
const graphics = @import("../graphics.zig");

const freetype = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("freetype2/ft2build.h");
});

var ft: freetype.FT_Library = undefined;
var face: freetype.FT_Face = undefined;

const charecter = struct {
    uvoffset: [2]f32,
    uvsize: [2]f32,
    offsetpx: [2]c_uint,
    sizepx: [2]c_uint,
    bearing: [2]c_long,
    Advance: c_long,
};

fn initilizefreetype(allocator: std.mem.Allocator, countp: *u32, chardata: *[]charecter, atlas: *[]u8, atlaswidth: *usize, atlasheight: *usize) !void {
    if (freetype.FT_Init_FreeType(&ft) != freetype.FT_Err_Ok) {
        std.log.err("Failed to initialize freetype liberary", .{});
        //main.running = false;
        return;
    }

    if (freetype.FT_New_Face(ft, "/usr/share/fonts/liberation/LiberationMono-Regular.ttf", 0, &face) != freetype.FT_Err_Ok) {
        std.log.err("Failed to load freetype face", .{});
        //main.running = false;
        return;
    }

    _ = freetype.FT_Set_Pixel_Sizes(face, 0, 48);
    if (freetype.FT_Select_Charmap(face, freetype.ft_encoding_unicode) != freetype.FT_Err_Ok) {
        std.log.err("Failed to select char map face", .{});
        //main.running = false;
        return;
    }

    atlaswidth.* = 0;
    atlasheight.* = 0;

    countp.* = 94;
    chardata.* = try allocator.alloc(charecter, countp.*);
    const interglyphpadding = 4;
    var count: usize = 0;
    for (0..10) |_| {
        var lineheight: usize = 0;
        var linewidth: usize = 0;
        for (0..10) |_| {
            if (count == 94) break;
            if (freetype.FT_Load_Char(face, 33 + count, freetype.FT_LOAD_RENDER) != freetype.FT_Err_Ok) {
                std.log.err("Failed to load freetype glyph", .{});
                return;
            }
            chardata.*[count].offsetpx[0] = @intCast(linewidth + interglyphpadding / 2);
            chardata.*[count].offsetpx[1] = @intCast(atlasheight.* + interglyphpadding / 2);
            chardata.*[count].sizepx[0] = face.*.glyph.*.bitmap.width;
            chardata.*[count].sizepx[1] = face.*.glyph.*.bitmap.rows;
            lineheight = @max(face.*.glyph.*.bitmap.rows + interglyphpadding, lineheight);
            linewidth = linewidth + face.*.glyph.*.bitmap.width + interglyphpadding;
            chardata.*[count].bearing = .{ face.*.glyph.*.metrics.horiBearingX, face.*.glyph.*.metrics.horiBearingY };
            chardata.*[count].Advance = face.*.glyph.*.advance.x;

            count = count + 1;
        }

        atlaswidth.* = @max(linewidth, atlaswidth.*);
        atlasheight.* = lineheight + atlasheight.*;
    }
    //calculate position in uv
    for (0..countp.*) |i| {
        chardata.*[i].uvoffset = .{
            @as(f32, @floatFromInt(chardata.*[i].offsetpx[0])) / @as(f32, @floatFromInt(atlaswidth.*)),
            @as(f32, @floatFromInt(chardata.*[i].offsetpx[1])) / @as(f32, @floatFromInt(atlasheight.*)),
        };
        chardata.*[i].uvsize = .{
            @as(f32, @floatFromInt(chardata.*[i].sizepx[0])) / @as(f32, @floatFromInt(atlaswidth.*)),
            @as(f32, @floatFromInt(chardata.*[i].sizepx[1])) / @as(f32, @floatFromInt(atlasheight.*)),
        };
    }

    //atlas creation logic
    atlas.* = try allocator.alloc(u8, atlaswidth.* * atlasheight.*);
    for (0..atlas.*.len) |i| {
        atlas.*[i] = 0;
    }

    for (33..127) |i| {
        if (freetype.FT_Load_Char(face, i, freetype.FT_LOAD_RENDER) != freetype.FT_Err_Ok) {
            std.log.err("Failed to load freetype glyph", .{});
            return;
        }
        //if pitch is negative rows are stored bottom to top

        if (face.*.glyph.*.bitmap.pitch < 0) {
            for (0..face.*.glyph.*.bitmap.rows) |rows| {
                const src = face.*.glyph.*.bitmap.buffer + @as(c_uint, @intCast(-face.*.glyph.*.bitmap.pitch)) * (face.*.glyph.*.bitmap.rows - 1 - @as(c_uint, @intCast(rows)));

                const dst = atlas.*[((chardata.*[i - 33].offsetpx[1] + rows) * atlaswidth.* + chardata.*[i - 33].offsetpx[0])..][0..face.*.glyph.*.bitmap.width];
                for (0..face.*.glyph.*.bitmap.width) |byte| {
                    dst[byte] = src[byte];
                }
            }
        } else {
            for (0..face.*.glyph.*.bitmap.rows) |rows| {
                const src = face.*.glyph.*.bitmap.buffer + @as(c_uint, @intCast(face.*.glyph.*.bitmap.pitch)) * @as(c_uint, @intCast(rows));
                const dst = atlas.*[((chardata.*[i - 33].offsetpx[1] + rows) * atlaswidth.* + chardata.*[i - 33].offsetpx[0])..][0..face.*.glyph.*.bitmap.width];
                for (0..face.*.glyph.*.bitmap.width) |byte| {
                    dst[byte] = src[byte];
                }
            }
        }
    }

    //for (atlas.*, 1..) |value, i| {
    //    if (value < 64) {
    //        std.debug.print(".", .{});
    //    } else if (value == 'a') {
    //        std.debug.print("a", .{});
    //    } else if (value < 128) {
    //        std.debug.print("|", .{});
    //    } else if (value < 192) {
    //        std.debug.print("H", .{});
    //    } else if (value > 192) {
    //        std.debug.print("#", .{});
    //    }
    //
    //    if (i % atlaswidth.* == 0 and i != 0) std.debug.print("\n", .{});
    //}
    _ = freetype.FT_Done_Face(face);
    _ = freetype.FT_Done_FreeType(ft);
}

pub const textrenderer = struct {
    allocator: std.mem.Allocator,
    count: u32,
    chardata: []charecter,
    atlas: []u8,
    atlaswidth: usize,
    atlasheight: usize,
    data: drawing.uniformbufferobject_text_rendering_data,
    pub fn init(allocator: std.mem.Allocator) !*textrenderer {
        const self = try allocator.create(textrenderer);
        self.allocator = allocator;
        try initilizefreetype(allocator, &self.count, &self.chardata, &self.atlas, &self.atlaswidth, &self.atlasheight);
        for (0..94) |i| {
            self.data.size[i] = .{ self.chardata[i].uvsize[0], self.chardata[i].uvsize[1], 0, 0 };
            self.data.offset[i] = .{ self.chardata[i].uvoffset[0], self.chardata[i].uvoffset[1], 0, 0 };
        }

        return self;
    }
    pub fn deinit(self: *textrenderer) void {
        self.allocator.free(self.chardata);
        self.allocator.free(self.atlas);
        self.allocator.destroy(self);
    }
};
const drawing = @import("../drawing.zig");
