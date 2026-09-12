const std = @import("std");
const Frame = @import("Frame.zig");

pub fn FrameWorker(comptime Context: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        io_backend: std.Io.Threaded,
        items: []?*Frame,
        head: usize,
        len: usize,
        mutex: std.Io.Mutex,
        wake: std.Io.Event,
        stopping: std.atomic.Value(bool),
        thread: ?std.Thread,

        ctx: *Context,
        handle_execute: *const fn (*Context, frame: *Frame) anyerror!void,

        pub const Options = struct {
            ctx: *Context,
            handle_execute: *const fn (*Context, frame: *Frame) anyerror!void,
            capacity: usize = 6,
        };

        pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
            if (opts.capacity == 0) return error.InvalidCapacity;

            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            const items = try allocator.alloc(?*Frame, opts.capacity);
            errdefer allocator.free(items);
            @memset(items, null);

            self.* = .{
                .allocator = allocator,
                .io_backend = .init_single_threaded,
                .items = items,
                .head = 0,
                .len = 0,
                .mutex = .init,
                .wake = .unset,
                .stopping = .init(false),
                .thread = null,
                .ctx = opts.ctx,
                .handle_execute = opts.handle_execute,
            };
            return self;
        }

        pub fn run(self: *Self) !void {
            if (self.thread != null) return error.AlreadyRunning;
            self.thread = try std.Thread.spawn(.{}, handleThreadRun, .{self});
        }

        pub fn deinit(self: *Self) void {
            if (self.thread) |thread| {
                self.stopping.store(true, .release);
                self.wake.set(self.io_backend.io());
                thread.join();
            }

            for (self.items) |frame| {
                if (frame) |item| item.destroy();
            }
            self.allocator.free(self.items);
            self.allocator.destroy(self);
        }

        pub fn count(self: *Self) usize {
            std.Io.Threaded.mutexLock(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);

            return self.len;
        }

        /// Takes ownership of `frame`. When full, merges its duration into the tail.
        pub fn push(self: *Self, frame: *Frame) void {
            if (self.stopping.load(.acquire)) {
                frame.destroy();
                return;
            }

            std.Io.Threaded.mutexLock(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);

            if (self.stopping.load(.acquire)) {
                frame.destroy();
                return;
            }

            if (self.len == self.items.len) {
                const tail = (self.head + self.len - 1) % self.items.len;
                const last = self.items[tail].?;
                last.addDuration(frame.duration);
                frame.destroy();
                return;
            }

            const tail = (self.head + self.len) % self.items.len;
            std.debug.assert(self.items[tail] == null);
            self.items[tail] = frame;
            self.len += 1;
            self.wake.set(self.io_backend.io());
        }

        fn shift(self: *Self) ?*Frame {
            std.Io.Threaded.mutexLock(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);

            if (self.len == 0) return null;

            const frame = self.items[self.head].?;
            self.items[self.head] = null;
            self.head = (self.head + 1) % self.items.len;
            self.len -= 1;
            return frame;
        }

        fn handleThreadRun(self: *Self) void {
            const io = self.io_backend.io();
            while (true) {
                self.wake.waitUncancelable(io);
                self.wake.reset();
                if (self.stopping.load(.acquire)) return;

                while (self.shift()) |frame| {
                    self.handle_execute(self.ctx, frame) catch |err| {
                        std.log.err("frame worker execution failed: {s}", .{@errorName(err)});
                    };
                }
            }
        }
    };
}
