const std = @import("std");
const Capture = @import("../Capture/Self.zig");
const Surface = @import("../Capture/_update_surface.zig").Surface;

pub const Frame = @import("Frame.zig");

const Self = @This();
const Thread = @import("Thread.zig").Thread(Self);
pub const OutputHandler = struct { ctx: *anyopaque, handle: *const fn (*anyopaque, *Frame) void };

allocator: std.mem.Allocator,
thread: *Thread,
interval_ns: u64,
capture: *Capture,
surface: ?Surface,
surface_mutex: std.Io.Mutex,
output_handlers: std.ArrayList(OutputHandler),
output_handlers_mutex: std.Io.Mutex,

pub fn init(
    allocator: std.mem.Allocator,
    interval_ns: u64,
    capture: *Capture,
) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.allocator = allocator;
    self.interval_ns = interval_ns;
    self.capture = capture;
    self.surface = null;
    self.surface_mutex = .init;
    self.output_handlers = .empty;
    self.output_handlers_mutex = .init;

    self.thread = try Thread.init(allocator, .{
        .ctx = self,
        .handle_render = handleRender,
        .handle_output = handleOutput,
        .interval_ns = interval_ns,
    });
    errdefer self.thread.deinit();

    return self;
}

pub fn deinit(self: *Self) void {
    self.thread.deinit();

    std.Io.Threaded.mutexLock(&self.surface_mutex);
    const prev = self.surface;
    self.surface = null;
    if (prev) |obj| obj.deinit();
    std.Io.Threaded.mutexUnlock(&self.surface_mutex);

    self.output_handlers.deinit(self.allocator);

    self.allocator.destroy(self);
}

pub fn addOutputHandler(self: *Self, handler: OutputHandler) !void {
    std.Io.Threaded.mutexLock(&self.output_handlers_mutex);
    defer std.Io.Threaded.mutexUnlock(&self.output_handlers_mutex);

    try self.output_handlers.append(self.allocator, handler);
}

pub fn removeOutputHandler(self: *Self, handler: OutputHandler) !void {
    std.Io.Threaded.mutexLock(&self.output_handlers_mutex);
    defer std.Io.Threaded.mutexUnlock(&self.output_handlers_mutex);

    for (self.output_handlers.items, 0..) |item, idx| {
        if (item.ctx != handler.ctx) continue;
        if (item.handle != handler.handle) continue;
        _ = self.output_handlers.orderedRemove(idx);
        return;
    }

    return error.OutputHandlerNotFound;
}

fn handleRender(self: *Self) void {
    const surface = self.capture.get_surface() orelse return;

    std.Io.Threaded.mutexLock(&self.surface_mutex);
    const prev = self.surface;
    self.surface = surface;
    if (prev) |obj| obj.deinit();
    std.Io.Threaded.mutexUnlock(&self.surface_mutex);
}

fn handleOutput(self: *Self, timestamp_ns: u64, frame_count: u32) void {
    const duration_ns = self.interval_ns *| @as(u64, frame_count);

    std.Io.Threaded.mutexLock(&self.surface_mutex);
    const frame = if (self.surface) |surface|
        Frame.init(self.allocator, surface.ref, timestamp_ns, duration_ns, frame_count) catch null
    else
        null;
    std.Io.Threaded.mutexUnlock(&self.surface_mutex);

    const output_frame = frame orelse return;
    defer output_frame.release();

    std.Io.Threaded.mutexLock(&self.output_handlers_mutex);
    for (self.output_handlers.items) |handler| {
        handler.handle(handler.ctx, output_frame);
    }
    std.Io.Threaded.mutexUnlock(&self.output_handlers_mutex);
}
