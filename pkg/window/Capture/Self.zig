const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const SCStream = @import("SCStream/Self.zig");
const SCStreamConfiguration = @import("SCStreamConfiguration/Self.zig");
const Surface = @import("_update_surface.zig").Surface;

const cg = macos.CoreGraphics;

const log = std.log.scoped(.capture);

const Self = @This();

allocator: std.mem.Allocator,
delegate: objc.Object,
stream: SCStream,

config: SCStreamConfiguration,
// CGRect frame;

// states
frame: ?cg.CGRect,
surface: ?Surface,
output_mutex: std.Io.Mutex,
err: ?objc.Object,
err_mutex: std.Io.Mutex,

pub const Options = struct {
    allocator: std.mem.Allocator,
    target: objc.Object, // window
    frame_interval_value: i64,
    frame_interval_timescale: i32,
    shows_cursor: bool,
};

pub fn init(
    opts: Options,
) !*Self {
    if (!cg.CGPreflightScreenCaptureAccess() and (!cg.CGRequestScreenCaptureAccess())) {
        log.err("capture requires Screen Recording permission", .{});
        return error.CaptureUnavailable;
    }

    const allocator = opts.allocator;

    const ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);

    ptr.allocator = allocator;
    ptr.frame = null;
    ptr.surface = null;
    ptr.output_mutex = .init;
    ptr.err = null;
    ptr.err_mutex = .init;
    @import("_delegate.zig")._init_delegate(ptr);
    @import("_init_stream.zig")._init_stream(ptr, opts.target);

    try ptr.stream.addStreamOutput(ptr.delegate);
    try ptr.stream.startCapture();

    return ptr;
}

pub fn deinit(self: *Self) void {
    self.stream.deinit();
    self.config.deinit();
    @import("_delegate.zig")._deinit_delegate(self);

    std.Io.Threaded.mutexLock(&self.output_mutex);
    @import("_update_surface.zig")._update(self, null);
    @import("_update_frame.zig")._update(self, null);
    std.Io.Threaded.mutexUnlock(&self.output_mutex);

    std.Io.Threaded.mutexLock(&self.err_mutex);
    @import("_update_err.zig")._update(self, null);
    std.Io.Threaded.mutexUnlock(&self.err_mutex);

    self.allocator.destroy(self);
}

pub fn take_surface(self: *Self) ?Surface {
    std.Io.Threaded.mutexLock(&self.output_mutex);
    defer std.Io.Threaded.mutexUnlock(&self.output_mutex);

    const surface = self.surface;
    self.surface = null;
    return surface;
}

pub fn take_err(self: *Self) ?objc.Object {
    std.Io.Threaded.mutexLock(&self.err_mutex);
    defer std.Io.Threaded.mutexUnlock(&self.err_mutex);

    const err = self.err;
    self.err = null;
    return err;
}
