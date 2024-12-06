const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

pub fn main() !void {
    const screnWidth: f32 = 400;
    const screnHeight: f32 = 800;
    r.InitWindow(screnWidth, screnHeight, "test");

    const image = r.LoadImage("./zero.png");
    var scale: f32 = 1;

    var widthPaddingNeeded = false;

    if (image.width > screnWidth) {
        scale = screnWidth / @as(f32, @floatFromInt(image.width));

        if (@as(f32, @floatFromInt(image.height)) * scale > screnHeight) {
            scale = screnHeight / @as(f32, @floatFromInt(image.height));
            widthPaddingNeeded = true;
        }
    }
    std.debug.print("scale {d} \n", .{scale});
    const realImageDimension: @Vector(2, u32) = .{ @intCast(image.width), @intCast(image.height) };
    var scaledImageDimesion: @Vector(2, f32) = @floatFromInt(realImageDimension);
    scaledImageDimesion *= @splat(scale);
    std.log.debug("{d}", .{scaledImageDimesion});
    r.SetTargetFPS(1);

    const im = r.LoadTextureFromImage(image);
    r.UnloadImage(image);
    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        defer r.EndDrawing();
        r.ClearBackground(r.WHITE);
        r.DrawTextureEx(im, .{
            .x = if (widthPaddingNeeded) screnWidth / 2 - scaledImageDimesion[0] / 2 else 0,
            .y = if (!widthPaddingNeeded) screnHeight / 2 - scaledImageDimesion[1] / 2 else 0,
        }, 0, scale, r.WHITE);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
