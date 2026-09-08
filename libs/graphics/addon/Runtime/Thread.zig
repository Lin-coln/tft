const std = @import("std");

const dispatch = std.c.dispatch;

pub fn Thread(comptime Context: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        wake: dispatch.semaphore_t,
        stopping: std.atomic.Value(bool),
        thread: std.Thread,
        ctx: *Context,
        handle_run: *const fn (*Context) void,

        pub const Options = struct {
            ctx: *Context,
            handle_run: *const fn (*Context) void,
        };

        pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
            const self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.allocator = allocator;
            self.wake = dispatch.semaphore_create(0).?;
            errdefer dispatch.release(self.wake.as_object());
            self.stopping = .init(false);
            self.ctx = opts.ctx;
            self.handle_run = opts.handle_run;
            self.thread = try std.Thread.spawn(.{}, handleThreadRun, .{self});

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.stopping.store(true, .release);
            self.notify();
            self.thread.join();
            dispatch.release(self.wake.as_object());
            self.allocator.destroy(self);
        }

        pub fn notify(self: *Self) void {
            _ = dispatch.semaphore_signal(self.wake);
        }

        fn handleThreadRun(self: *Self) void {
            while (true) {
                _ = dispatch.semaphore_wait(self.wake, .FOREVER);
                if (self.stopping.load(.acquire)) return;
                self.handle_run(self.ctx);
            }
        }
    };
}
