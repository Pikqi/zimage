const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

pub fn main() !void {
    const image = r.LoadImage("./zero.png");
    var windowWidth: c_int = image.width;
    var windowHeight: c_int = image.height;
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_RESIZABLE);
    r.InitWindow(windowWidth, windowHeight, "zimage");

    const realImageDimension: @Vector(2, u32) = .{ @intCast(image.width), @intCast(image.height) };

    var scaledImageDimension: @Vector(2, f32) = undefined;
    var imagePosX: f32 = undefined;
    var imagePosY: f32 = undefined;
    var scale: f32 = 1;
    rescale(&imagePosX, &imagePosY, &scaledImageDimension, realImageDimension, &scale);

    const im = r.LoadTextureFromImage(image);
    r.UnloadImage(image);
    while (!r.WindowShouldClose()) {
        if (r.GetRenderHeight() != windowHeight or windowWidth != r.GetRenderWidth()) {
            windowHeight = r.GetRenderHeight();
            windowWidth = r.GetRenderWidth();
            rescale(&imagePosX, &imagePosY, &scaledImageDimension, realImageDimension, &scale);
        }

        r.BeginDrawing();
        defer r.EndDrawing();
        r.ClearBackground(r.WHITE);
        r.DrawTextureEx(im, .{
            .x = imagePosX,
            .y = imagePosY,
        }, 0, scale, r.WHITE);
    }
}

fn rescale(
    imagePosX: *f32,
    imagePosY: *f32,
    scaledImageDimension: *@Vector(2, f32),
    realImageDimension: @Vector(2, u32),
    scale: *f32,
) void {
    const windowWidth = r.GetRenderWidth();
    const windowHeight = r.GetRenderHeight();
    scale.* = 1;
    // image is bigger than screen
    if (realImageDimension[0] > windowWidth) {
        scale.* = @as(f32, @floatFromInt(windowWidth)) / @as(f32, @floatFromInt(realImageDimension[0]));
    }
    if (realImageDimension[1] > windowHeight) {
        scale.* = @min(scale.*, @as(f32, @floatFromInt(windowHeight)) / @as(f32, @floatFromInt(realImageDimension[1])));
    }
    // image is smaller than screen
    if (realImageDimension[0] < windowWidth) {
        scale.* = @min(scale.*, @as(f32, @floatFromInt(windowHeight)) / @as(f32, @floatFromInt(realImageDimension[1])));
    }
    if (realImageDimension[1] < windowHeight) {
        scale.* = @min(scale.*, @as(f32, @floatFromInt(windowHeight)) / @as(f32, @floatFromInt(realImageDimension[1])));
    }

    // not sure why this gives an type eror
    // scaledImageDimension.* = @as(@Vector(2, f32), @splat(scale.*)) * @as(f32, @floatFromInt(realImageDimension));
    scaledImageDimension.* = @floatFromInt(realImageDimension);
    scaledImageDimension.* *= @splat(scale.*);

    const widthPaddingNeeded = scaledImageDimension.*[0] < @as(f32, @floatFromInt(windowWidth));

    imagePosX.* = if (widthPaddingNeeded) @as(f32, @floatFromInt(windowWidth)) / 2.0 - scaledImageDimension.*[0] / 2.0 else 0;
    imagePosY.* = if (!widthPaddingNeeded) @as(f32, @floatFromInt(windowHeight)) / 2.0 - scaledImageDimension.*[1] / 2.0 else 0;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
