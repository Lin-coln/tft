const std = @import("std");
const macos = @import("macos");
const Renderer = @import("../Renderer/Self.zig");
const Queue = @import("Queue.zig");
const Encoder = @import("../Encoder/Self.zig");

const cm = macos.CoreMedia;
const Frame = Renderer.Frame;
const Packet = Encoder.Packet;

const Self = @This();
const Thread = @import("Thread.zig").Thread(Self);

allocator: std.mem.Allocator,
queue: *Queue,
thread: *Thread,
encoder: *Encoder,
ctx: *anyopaque,
handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,

pub const Options = struct {
    ctx: *anyopaque,
    handle_output: *const fn (ctx: *anyopaque, borrowed: *Packet) void,
};
pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.allocator = allocator;
    self.ctx = opts.ctx;
    self.handle_output = opts.handle_output;
    self.queue = try Queue.init(allocator);
    errdefer self.queue.deinit();

    self.thread = try Thread.init(allocator, .{
        .ctx = self,
        .handle_run = handleReceiveFrame,
    });
    errdefer self.thread.deinit();

    self.encoder = try Encoder.init(allocator, .{
        .ctx = self,
        .handle_error = handleEncodeError,
        .handle_output = handleEncodeOutput,
    });
    errdefer self.encoder.deinit();

    return self;
}

pub fn deinit(self: *Self) void {
    self.thread.deinit();
    self.encoder.deinit();
    self.queue.deinit();
    self.allocator.destroy(self);
}

pub fn onReceiveFrame(ctx: *anyopaque, frame: *Frame) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.queue.push(frame);
    self.thread.notify();
}

fn handleReceiveFrame(self: *Self) void {
    const frame = self.queue.shift() orelse return;
    defer frame.release();

    self.encoder.encode(frame) catch |err| {
        handleEncodeError(self, err);
    };
}

fn handleEncodeError(ctx: *anyopaque, err: anyerror) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
    @panic(@errorName(err));
}

fn handleEncodeOutput(
    ctx: *anyopaque,
    borrowed: *Frame,
    sample_buffer: cm.CMSampleBufferRef,
) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const packet = try Packet.fromSampleBuffer(
        self.allocator,
        borrowed,
        sample_buffer,
    );
    defer packet.release();

    self.handle_output(self.ctx, packet);
}
