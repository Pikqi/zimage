const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

const transparent = std.mem.zeroInit(r.Color, .{ 255, 255, 255, 125 });

const ImageToShow = struct {
    texture: r.Texture,
    dimension: @Vector(2, u32),
    nameZ: [:0]u8,
};

fn isSupportedPicture(imgName: []const u8) bool {
    return std.mem.endsWith(u8, imgName, ".png") or
        std.mem.endsWith(u8, imgName, ".jpg");
}
const WindowInfo = struct {
    bottom_padding: c_int = 50,
    horizontalScroll: c_int = 0,
    thumbnail_margin: c_int = 20,
    windowWidth: c_int = 1,
    windowHeight: c_int = 1,
    thumbarWidth: c_int,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var argsIter = try std.process.argsWithAllocator(alloc);
    defer argsIter.deinit();

    _ = argsIter.skip();
    const filenameArg = argsIter.next();
    var argIsFile = false;

    var path = try std.fs.cwd().realpathAlloc(alloc, ".");
    if (filenameArg) |filename| {
        if (std.fs.cwd().realpathAlloc(alloc, filename)) |pathVal| {
            alloc.free(path);
            path = pathVal;
            if (isSupportedPicture(path)) {
                argIsFile = true;
            }
        } else |e| {
            if (e == error.FileNotFound) {
                std.log.warn("Arg is not a valid image path, will defaut to current folder ", .{});
            } else {
                return;
            }
        }
    }
    defer alloc.free(path);

    // Window must be init before texure loading (opengl context must be available)
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_RESIZABLE);
    r.InitWindow(800, 600, "zimage");

    var imagesList = try std.ArrayList(ImageToShow).initCapacity(alloc, 5);
    defer imagesList.deinit();
    defer {
        for (imagesList.items) |value| {
            alloc.free(value.nameZ);
        }
    }

    if (!argIsFile) {
        var a = try std.fs.openDirAbsolute(path, .{ .access_sub_paths = false, .iterate = true });
        var it = a.iterate();
        while (try it.next()) |val| {
            if (val.kind != .file) {
                continue;
            }
            if (isSupportedPicture(val.name)) {
                const fullPath = try std.mem.concat(alloc, u8, &.{ path, "/", val.name });
                defer alloc.free(fullPath);

                const pathDupe = try alloc.dupeZ(u8, fullPath);
                defer alloc.free(pathDupe);

                const image = r.LoadImage(pathDupe);
                defer r.UnloadImage(image);

                if (image.height == 0 or image.width == 0) {
                    std.log.warn("file skipped: {s} \n", .{fullPath});
                    continue;
                }

                const texture = r.LoadTextureFromImage(image);

                try imagesList.append(ImageToShow{ .texture = texture, .dimension = .{
                    @intCast(image.width),
                    @intCast(image.height),
                }, .nameZ = try alloc.dupeZ(u8, val.name) });
            }
        }
    } else {
        // try imagePath;
    }

    if (imagesList.items.len == 0) {
        std.log.warn("No images to show, exiting.", .{});
        return;
    }

    var selected_image_index: usize = 0;
    var selected_image = imagesList.items[selected_image_index];

    var imagePosX: f32 = undefined;
    var imagePosY: f32 = undefined;
    var scale: f32 = 1;

    var windowInfo: WindowInfo = .{ .thumbarWidth = undefined };

    windowInfo.thumbarWidth = @as(c_int, @intCast(imagesList.items.len)) * (windowInfo.bottom_padding + @as(c_int, @intCast(windowInfo.thumbnail_margin)));

    rescale(&imagePosX, &imagePosY, selected_image.dimension, &scale, windowInfo.bottom_padding);

    var mousePosition = r.GetMousePosition();
    var mouseClicked = false;
    while (!r.WindowShouldClose()) {
        windowInfo.bottom_padding = @divFloor(windowInfo.windowHeight, 5);
        if (r.GetRenderHeight() != windowInfo.windowHeight or windowInfo.windowWidth != r.GetRenderWidth()) {
            windowInfo.windowHeight = r.GetRenderHeight();
            windowInfo.windowWidth = r.GetRenderWidth();
            rescale(&imagePosX, &imagePosY, selected_image.dimension, &scale, windowInfo.bottom_padding);
        }

        // MOUSE INPUT
        mouseClicked = false;
        if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
            mouseClicked = true;
            mousePosition = r.GetMousePosition();
        }

        //  VERTICAL SCROLL
        if (r.GetMouseWheelMoveV().y != 0) {
            if (pointIntersectsRectangle(.{ r.GetMousePosition().x, r.GetMousePosition().y }, 0, @floatFromInt(windowInfo.windowHeight - windowInfo.bottom_padding), @floatFromInt(windowInfo.windowWidth), @floatFromInt(windowInfo.windowHeight))) {
                const wantedIndex: usize = @intCast(@max(@as(isize, @intCast(selected_image_index)) + @as(isize, @intFromFloat(r.GetMouseWheelMoveV().y)), 0));
                setImageIndex(wantedIndex, &selected_image_index, &selected_image, &imagesList, &imagePosX, &imagePosY, &scale, &windowInfo);
            }
        }
        // HORIZONTAL SCROLL
        if (r.GetMouseWheelMoveV().x != 0) {
            if (pointIntersectsRectangle(.{ r.GetMousePosition().x, r.GetMousePosition().y }, 0, @floatFromInt(windowInfo.windowHeight - windowInfo.bottom_padding), @floatFromInt(windowInfo.windowWidth), @floatFromInt(windowInfo.windowHeight))) {
                windowInfo.horizontalScroll = clamp(windowInfo.horizontalScroll + 60 * @as(c_int, @intFromFloat(r.GetMouseWheelMoveV().x)), 0, windowInfo.thumbarWidth);
            }
        }

        // KEYBOARD INPUT

        if (r.IsKeyPressed(r.KEY_RIGHT)) {
            setImageIndex(selected_image_index + 1, &selected_image_index, &selected_image, &imagesList, &imagePosX, &imagePosY, &scale, &windowInfo);
        }
        if (r.IsKeyPressed(r.KEY_LEFT)) {
            if (selected_image_index != 0) {
                setImageIndex(selected_image_index - 1, &selected_image_index, &selected_image, &imagesList, &imagePosX, &imagePosY, &scale, &windowInfo);
            }
        }

        // DRAW
        r.BeginDrawing();
        defer r.EndDrawing();
        r.ClearBackground(r.WHITE);
        r.DrawTextureEx(selected_image.texture, .{
            .x = imagePosX,
            .y = imagePosY,
        }, 0, scale, r.WHITE);

        r.DrawText(selected_image.nameZ, 20, 20, 40, r.BLACK);

        // THUMNAILS
        for (imagesList.items, 0..) |image, i| {
            const small_image_scale = rescale_thumnail(image.dimension, windowInfo.bottom_padding, windowInfo.bottom_padding);
            const x: f32 = @floatFromInt(@as(c_int, @intCast(i)) * (windowInfo.bottom_padding + windowInfo.thumbnail_margin) - windowInfo.horizontalScroll);
            const y: f32 = @floatFromInt(windowInfo.windowHeight - windowInfo.bottom_padding);

            r.DrawTextureEx(image.texture, .{
                .x = x,
                .y = y,
            }, 0, small_image_scale, if (selected_image_index == i) r.WHITE else transparent);
            if (mouseClicked) {
                if (pointIntersectsRectangle(.{ mousePosition.x, mousePosition.y }, x, y, @floatFromInt(windowInfo.bottom_padding), @floatFromInt(windowInfo.bottom_padding))) {
                    setImageIndex(i, &selected_image_index, &selected_image, &imagesList, &imagePosX, &imagePosY, &scale, &windowInfo);
                }
            }
        }
        // END THUMNAILS
    }
}

fn setImageIndex(
    new_image_index: usize,
    selected_image_index: *usize,
    selected_image: *ImageToShow,
    imagesList: *std.ArrayList(ImageToShow),
    imagePosX: *f32,
    imagePosY: *f32,
    scale: *f32,
    windowInfo: *WindowInfo,
) void {
    selected_image_index.* = clamp(new_image_index, 0, imagesList.items.len - 1);

    selected_image.* = imagesList.items[selected_image_index.*];
    rescale(imagePosX, imagePosY, selected_image.dimension, scale, windowInfo.bottom_padding);

    const elementThumbPosition: c_int = @as(c_int, @intCast(selected_image_index.*)) * (windowInfo.bottom_padding + windowInfo.thumbnail_margin);

    windowInfo.horizontalScroll = clamp(elementThumbPosition, 0, windowInfo.thumbarWidth + (windowInfo.bottom_padding + windowInfo.thumbnail_margin));
}
fn pointIntersectsRectangle(point: @Vector(2, f32), x: f32, y: f32, width: f32, height: f32) bool {
    if (point[0] > x and point[0] < x + width) {
        if (point[1] > y and point[1] < y + height) {
            return true;
        }
    }
    return false;
}

fn clamp(val: anytype, min: @TypeOf(val), max: @TypeOf(val)) @TypeOf(val) {
    if (val >= max) {
        return max;
    }
    if (val <= min) {
        return min;
    }
    return val;
}

fn rescale_thumnail(
    realImageDimension: @Vector(2, u32),
    height: i32,
    width: i32,
) f32 {
    var scale: f32 = 1;
    if (realImageDimension[0] > width) {
        scale = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(realImageDimension[0]));
    }
    if (realImageDimension[1] > height) {
        scale = @min(scale, @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(realImageDimension[1])));
    }
    if (scale != 1) {
        return scale;
    }
    // image is smaller than screen
    if (realImageDimension[0] < width) {
        scale = @max(scale, @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(realImageDimension[1])));
    }
    if (realImageDimension[1] < height) {
        scale = @max(scale, @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(realImageDimension[1])));
    }
    return scale;
}
fn rescale(
    imagePosX: *f32,
    imagePosY: *f32,
    realImageDimension: @Vector(2, u32),
    scale: *f32,
    bottom_padding: c_int,
) void {
    const windowWidth = r.GetRenderWidth();
    const windowHeight = r.GetRenderHeight() - bottom_padding;
    var scaledImageDimension: @Vector(2, f32) = undefined;
    scale.* = 1;
    // image is bigger than screen
    scaleBlk: {
        if (realImageDimension[0] > windowWidth) {
            scale.* = @as(f32, @floatFromInt(windowWidth)) / @as(f32, @floatFromInt(realImageDimension[0]));
        }
        if (realImageDimension[1] > windowHeight) {
            scale.* = @min(scale.*, @as(f32, @floatFromInt(windowHeight)) / @as(f32, @floatFromInt(realImageDimension[1])));
        }
        if (scale.* != 1) {
            break :scaleBlk;
        }
        // image is smaller than screen
        if (realImageDimension[0] < windowWidth) {
            scale.* = @max(scale.*, @as(f32, @floatFromInt(windowHeight)) / @as(f32, @floatFromInt(realImageDimension[1])));
        }
        if (realImageDimension[1] < windowHeight) {
            scale.* = @max(scale.*, @as(f32, @floatFromInt(windowHeight)) / @as(f32, @floatFromInt(realImageDimension[1])));
        }
    }

    // not sure why this gives an type eror
    // scaledImageDimension.* = @as(@Vector(2, f32), @splat(scale.*)) * @as(f32, @floatFromInt(realImageDimension));
    scaledImageDimension = @floatFromInt(realImageDimension);
    scaledImageDimension *= @splat(scale.*);

    const widthPaddingNeeded = scaledImageDimension[0] < @as(f32, @floatFromInt(windowWidth));

    imagePosX.* = if (widthPaddingNeeded) @as(f32, @floatFromInt(windowWidth)) / 2.0 - scaledImageDimension[0] / 2.0 else 0;
    imagePosY.* = if (!widthPaddingNeeded) @as(f32, @floatFromInt(windowHeight)) / 2.0 - scaledImageDimension[1] / 2.0 else 0;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
