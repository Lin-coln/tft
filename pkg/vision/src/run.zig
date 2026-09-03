const std = @import("std");
const vision = @import("vision");

const Infer = vision.Infer;

const max_image_bytes = 32 * 1024 * 1024;

pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        if (err != error.Reported) {
            report(init.io, "error: {s}\n", .{@errorName(err)});
        }
        std.process.exit(1);
    };
}

fn run(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) {
        report(init.io, "usage: {s} <image.png>\n", .{args[0]});
        return error.Reported;
    }

    const path = args[1];
    const png_bytes = std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        allocator,
        .limited(max_image_bytes),
    ) catch |err| {
        report(init.io, "failed to read image '{s}': {s}\n", .{ path, @errorName(err) });
        return error.Reported;
    };
    defer allocator.free(png_bytes);

    const image_data = vision.allocNSDataFromBytes(png_bytes) catch |err| {
        report(init.io, "failed to create image data for '{s}': {s}\n", .{ path, @errorName(err) });
        return error.Reported;
    };
    defer image_data.release();

    const inference = Infer.init(.{ .allocator = allocator }) catch |err| {
        report(init.io, "failed to initialize Vision: {s}\n", .{@errorName(err)});
        return error.Reported;
    };
    defer inference.deinit();

    const result = inference.run(.{ .data = image_data }, .{}) catch |err| {
        report(init.io, "failed to recognize text in '{s}': {s}\n", .{ path, @errorName(err) });
        return error.Reported;
    };
    defer result.deinit();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("image: {s}\n", .{path});
    try stdout.print("observations: {d}\n", .{result.observation_count});
    if (result.items.len == 0) {
        try stdout.writeAll("no text recognized\n");
    } else {
        var last_observation: ?usize = null;
        for (result.items) |item| {
            if (last_observation != item.observation) {
                try stdout.print("\nobservation[{d}]\n", .{item.observation});
                last_observation = item.observation;
            }
            try stdout.print(
                "  candidate[{d}]: text=\"{s}\" confidence={d:.4}\n",
                .{ item.candidate, item.string, item.confidence },
            );
        }
    }
    try stdout.flush();
}

fn report(io: std.Io, comptime format: []const u8, args: anytype) void {
    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
    const stderr = &stderr_writer.interface;
    stderr.print(format, args) catch return;
    stderr.flush() catch {};
}
