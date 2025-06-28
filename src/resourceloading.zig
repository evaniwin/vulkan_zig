pub fn loadmodel(allocator: std.mem.Allocator, Model: *parseobj.model, filename: []const u8) !void {
    const object = try parseobj.obj.init(allocator, filename);
    defer object.deinit();
    try object.processformatdata();
    Model.* = object.model;
}

fn user_error_fn(pngptr: png.png_structp, error_msg: [*c]const u8) callconv(.c) void {
    std.log.err("Libpng error: {s}", .{std.mem.span(error_msg)});
    const errorlibpng: *u8 = @ptrCast(png.png_get_error_ptr(pngptr));
    errorlibpng.* = 1;
}

fn user_warning_fn(_: png.png_structp, warning_msg: [*c]const u8) callconv(.c) void {
    std.log.warn("Libpng warning: {s}", .{std.mem.span(warning_msg)});
}
pub fn loadimage(allocator: std.mem.Allocator, miplevels: *u32, pwidth: *c_uint, pheight: *c_uint, filename: [*c]const u8) ![]u8 {
    const dir = std.c.fopen(filename, "rb");
    var errorlibpng: ?u8 = 0;
    if (dir == null) {
        std.log.err("unable to open texture file", .{});
        return error.UnableToOpenTextureFile;
    }
    defer _ = std.c.fclose(dir.?);
    var header: [8]u8 = undefined;
    const result = std.c.fread(&header, 1, header.len, dir.?);
    if (header.len != result) {
        std.log.err("unable to Read texture file", .{});
        return error.UnableToReadTextureFile;
    }
    const is_png = png.png_sig_cmp(&header[0], 0, header.len);
    if (is_png != 0) {
        std.log.err("The file signature dosent match a png", .{});
        return error.FileNotPng;
    }
    var pngptr: png.png_structp = png.png_create_read_struct(
        png.PNG_LIBPNG_VER_STRING,
        @ptrCast(&errorlibpng),
        user_error_fn,
        user_warning_fn,
    );
    if (pngptr == null) {
        std.log.err("unable to Create png pointer", .{});
        return error.UnableToCreatePngptr;
    }
    var pnginfoptr: png.png_infop = png.png_create_info_struct(pngptr);
    if (pnginfoptr == null) {
        std.log.err("unable to Create png info pointer", .{});
        png.png_destroy_read_struct(&pngptr, null, null);
        return error.UnableToCreatePngInfoptr;
    }
    var pngendinfoptr: png.png_infop = png.png_create_info_struct(pngptr);
    if (pngendinfoptr == null) {
        std.log.err("unable to Create png end info pointer", .{});
        png.png_destroy_read_struct(&pngptr, &pnginfoptr, null);
        return error.UnableToCreatePngEndInfoptr;
    }

    defer png.png_destroy_read_struct(&pngptr, &pnginfoptr, &pngendinfoptr);

    png.png_init_io(pngptr, @ptrCast(dir));
    png.png_set_sig_bytes(pngptr, header.len);

    png.png_set_expand(pngptr);
    png.png_set_strip_16(pngptr);
    png.png_set_palette_to_rgb(pngptr);
    png.png_set_gray_to_rgb(pngptr);
    png.png_set_tRNS_to_alpha(pngptr);
    png.png_set_add_alpha(pngptr, 0xFF, png.PNG_FILLER_AFTER);

    png.png_read_info(pngptr, pnginfoptr);

    pwidth.* = png.png_get_image_width(pngptr, pnginfoptr);
    pheight.* = png.png_get_image_height(pngptr, pnginfoptr);
    const width: usize = pwidth.*;
    const height: usize = pheight.*;
    miplevels.* = @intFromFloat(std.math.floor(std.math.log2(@as(f32, @floatFromInt(@max(width, height))))));

    const pixels: []u8 = try allocator.alloc(u8, height * width * 4);
    const rows: []png.png_bytep = try allocator.alloc(png.png_bytep, height);
    defer allocator.free(rows);
    for (0..height) |i| {
        rows[i] = &pixels[i * width * 4];
    }
    png.png_read_image(pngptr, &rows[0]);
    return pixels;
}
const png = @cImport({
    @cInclude("png.h");
});
pub const vk = graphics.vk;
const graphics = @import("graphics.zig");
const parseobj = @import("parseobj.zig");
const std = @import("std");
