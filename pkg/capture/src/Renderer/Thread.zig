const std = @import("std");
const dispatch = std.c.dispatch;

pub fn Thread(comptime Context: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        wake: dispatch.semaphore_t,
        stopping: std.atomic.Value(bool),
        interval_ns: u64,
        thread: std.Thread,

        ctx: *Context,
        handle_render: *const fn (*Context) void,
        handle_output: *const fn (*Context, u64, u32) void,

        pub const Options = struct {
            ctx: *Context,
            interval_ns: u64,
            handle_render: *const fn (*Context) void,
            handle_output: *const fn (*Context, u64, u32) void,
        };
        pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.allocator = allocator;
            self.wake = dispatch.semaphore_create(0).?;
            errdefer dispatch.release(self.wake.as_object());
            self.stopping = .init(false);
            self.interval_ns = opts.interval_ns;
            self.ctx = opts.ctx;
            self.handle_render = opts.handle_render;
            self.handle_output = opts.handle_output;
            self.thread = try std.Thread.spawn(.{}, handleThreadRun, .{self});
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.stopping.store(true, .release);
            _ = dispatch.semaphore_signal(self.wake);
            self.thread.join();
            dispatch.release(self.wake.as_object());
            self.allocator.destroy(self);
        }

        fn handleThreadRun(self: *Self) void {
            var threaded_io: std.Io.Threaded = .init_single_threaded;
            const io = threaded_io.io();
            const interval_ns: i96 = @intCast(self.interval_ns);
            var video_time_ns = std.Io.Clock.awake.now(io).toNanoseconds();

            while (!self.stopping.load(.acquire)) {
                const timestamp_ns: u64 = @intCast(video_time_ns);
                self.handle_render(self.ctx);
                const now_ns = std.Io.Clock.awake.now(io).toNanoseconds();
                const elapsed_ns = now_ns - video_time_ns;
                const frame_count = @max(1, @divFloor(elapsed_ns, interval_ns));

                self.handle_output(self.ctx, timestamp_ns, @intCast(frame_count));
                video_time_ns += interval_ns * frame_count;

                const remaining_ns = video_time_ns - now_ns;
                if (remaining_ns <= 0) continue;
                const deadline = dispatch.time(.NOW, @intCast(remaining_ns));
                _ = dispatch.semaphore_wait(self.wake, deadline);
            }
        }
    };
}
