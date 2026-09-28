const std = @import("std");
const macos = @import("macos");
const Infer = @import("../Infer/Self.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const ios = macos.IOSurface;
const log = std.log.scoped(.infer_session);

pub fn Of(comptime Source: type) type {
    return struct {
        const Self = @This();
        const Driver = @import("tft/pipeline").Driver.Of(Self, handleDriveLoop);

        allocator: Allocator,
        source: *Source,
        infer: *Infer = undefined,
        driver: *Driver = undefined,

        pub fn create(
            allocator: Allocator,
            opts: struct {
                source: *Source,
                framerate: u32,
            },
        ) !*Self {
            if (opts.framerate == 0) return error.InvalidFramerate;

            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .source = opts.source,
            };

            self.infer = try Infer.create(allocator, .{});
            errdefer self.infer.destroy();

            self.driver = try Driver.create(allocator, .{
                .ctx = self,
                .interval = .fromNanoseconds(std.time.ns_per_s / opts.framerate),
            });
            errdefer self.driver.destroy();

            try self.driver.start();
            return self;
        }

        pub fn destroy(self: *Self) void {
            self.driver.destroy();
            self.infer.destroy();
            self.allocator.destroy(self);
        }

        fn handleDriveLoop(self: *Self, ts: Io.Clock.Timestamp) ?Io.Duration {
            self.inferLatest() catch |err| {
                log.err("inference failed: {s}", .{@errorName(err)});
            };
            return self.driver.calcDuration(ts);
        }

        fn inferLatest(self: *Self) !void {
            const surface = self.source.getSurface() orelse return;
            defer surface.deinit();

            const results = try self.infer.run(.{ .io_surface = surface.ref }, .{});
            defer results.deinit();

            if (results.items.len == 0) {
                log.info("no text recognized", .{});
                return;
            }
            for (results.items) |item| {
                log.info("observation[{d}] candidate[{d}]: text=\"{s}\" confidence={d:.4}", .{
                    item.observation,
                    item.candidate,
                    item.string,
                    item.confidence,
                });
            }
        }
    };
}

const TestSource = struct {
    pub fn getSurface(_: *@This()) ?struct {
        ref: ios.IOSurfaceRef,

        pub fn deinit(_: @This()) void {}
    } {
        return null;
    }
};

test "create rejects a zero framerate" {
    const Session = Of(TestSource);
    var source: TestSource = .{};

    try std.testing.expectError(error.InvalidFramerate, Session.create(
        std.testing.allocator,
        .{
            .source = &source,
            .framerate = 0,
        },
    ));
}

test "driver starts and stops without a surface" {
    const Session = Of(TestSource);
    var source: TestSource = .{};

    const session = try Session.create(std.testing.allocator, .{
        .source = &source,
        .framerate = 60,
    });
    session.destroy();
}
