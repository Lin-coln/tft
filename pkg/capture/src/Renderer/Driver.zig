const std = @import("std");

pub fn Driver(
    comptime Context: type,
) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        io_backend: std.Io.Threaded,
        interval: std.Io.Duration,
        frame_ts: std.Io.Clock.Timestamp,
        stopping: std.Io.Event,
        thread: ?std.Thread,

        ctx: *Context,
        handle_loop: *const fn (*Context, ts: std.Io.Clock.Timestamp) ?std.Io.Duration,

        pub const Options = struct {
            ctx: *Context,
            interval: std.Io.Duration,
            handle_loop: *const fn (*Context, ts: std.Io.Clock.Timestamp) ?std.Io.Duration,
        };
        pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
            if (opts.interval.nanoseconds <= 0) return error.InvalidInterval;

            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .allocator = allocator,
                .io_backend = .init_single_threaded,
                .interval = opts.interval,
                .frame_ts = undefined,
                .stopping = .unset,
                .thread = null,
                .ctx = opts.ctx,
                .handle_loop = opts.handle_loop,
            };
            return self;
        }

        pub fn run(self: *Self) !void {
            if (self.thread != null) return error.AlreadyRunning;
            self.thread = try std.Thread.spawn(.{}, handleThreadRun, .{self});
        }

        pub fn deinit(self: *Self) void {
            if (self.thread) |thread| {
                self.stopping.set(self.io_backend.io());
                thread.join();
            }
            self.allocator.destroy(self);
        }

        pub fn calcDuration(self: *Self, from: std.Io.Clock.Timestamp) std.Io.Duration {
            const interval_ns = self.interval.nanoseconds;
            const now = std.Io.Clock.Timestamp.now(self.io_backend.io(), .awake);
            const elapsed = from.durationTo(now);
            const frame_count = @max(1, @divFloor(elapsed.raw.nanoseconds, interval_ns));
            return std.Io.Duration.fromNanoseconds(frame_count * interval_ns);
        }

        fn handleThreadRun(self: *Self) void {
            const io = self.io_backend.io();
            self.frame_ts = std.Io.Clock.Timestamp.now(io, .awake);
            while (true) {
                const offset = self.handle_loop(self.ctx, self.frame_ts) orelse self.interval;
                self.frame_ts = self.frame_ts.addDuration(.{ .raw = offset, .clock = .awake });
                self.stopping.waitTimeout(io, .{
                    .deadline = self.frame_ts,
                }) catch |err| switch (err) {
                    error.Timeout => continue,
                    error.Canceled => return,
                };
                return;
            }
        }
    };
}
