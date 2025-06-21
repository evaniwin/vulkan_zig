const std = @import("std");
const graphics = @import("../graphics.zig");

const freetype = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("freetype2/ft2build.h");
});

var ft: freetype.FT_Library = undefined;
var face: freetype.FT_Face = undefined;

pub const charecter = struct {
    uvoffset: [2]f32,
    uvsize: [2]f32,
    offsetpx: [2]c_uint,
    sizepx: [2]c_uint,
    bearing: [2]c_int,
    Advance: c_long,
};

pub fn initilizefreetype(allocator: std.mem.Allocator) !void {
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

    var atlaswidth: usize = 0;
    var atlasheight: usize = 0;
    var charecters: [94]charecter = undefined;
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
            charecters[count].offsetpx[0] = @intCast(linewidth + 1);
            charecters[count].offsetpx[1] = @intCast(atlasheight + 1);
            lineheight = @max(face.*.glyph.*.bitmap.rows + 2, lineheight);
            linewidth = linewidth + face.*.glyph.*.bitmap.width + 2;
            count = count + 1;
        }

        atlaswidth = @max(linewidth, atlaswidth);
        atlasheight = lineheight + atlasheight;
    }
    const atlas = try allocator.alloc(u8, atlaswidth * atlasheight);
    for (0..atlas.len) |i| {
        atlas[i] = 0;
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

                const dst = atlas[((charecters[i - 33].offsetpx[1] + rows) * atlaswidth + charecters[i - 33].offsetpx[0])..][0..face.*.glyph.*.bitmap.width];
                for (0..face.*.glyph.*.bitmap.width) |byte| {
                    dst[byte] = src[byte];
                }
            }
        } else {
            for (0..face.*.glyph.*.bitmap.rows) |rows| {
                const src = face.*.glyph.*.bitmap.buffer + @as(c_uint, @intCast(face.*.glyph.*.bitmap.pitch)) * @as(c_uint, @intCast(rows));
                const dst = atlas[((charecters[i - 33].offsetpx[1] + rows) * atlaswidth + charecters[i - 33].offsetpx[0])..][0..face.*.glyph.*.bitmap.width];
                for (0..face.*.glyph.*.bitmap.width) |byte| {
                    dst[byte] = src[byte];
                }
            }
        }
    }

    for (atlas, 1..) |value, i| {
        if (value < 64) {
            std.debug.print(".", .{});
        } else if (value == 'a') {
            std.debug.print("a", .{});
        } else if (value < 128) {
            std.debug.print("|", .{});
        } else if (value < 192) {
            std.debug.print("H", .{});
        } else if (value > 192) {
            std.debug.print("#", .{});
        }

        if (i % atlaswidth == 0 and i != 0) std.debug.print("\n", .{});
    }
    allocator.free(atlas);
    _ = freetype.FT_Done_Face(face);
    _ = freetype.FT_Done_FreeType(ft);
}
