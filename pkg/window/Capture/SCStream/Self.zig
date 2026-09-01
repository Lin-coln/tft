const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const dispatch = std.c.dispatch;
const ns = macos.Foundation;

pub const OutputType = enum(ns.NSInteger) {
    Screen = 0,
    Audio = 1,
    Microphone = 2,
};

const log = std.log.scoped(.capture_stream);

const Self = @This();

obj: objc.Object,
sample_queue: dispatch.queue_t,

pub fn init(
    filter: objc.Object,
    config: objc.Object,
    delegate: objc.Object,
) Self {
    const stream = init: {
        const Class = objc.getClass("SCStream").?;
        const id_alloc = Class.msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(
            objc.Object,
            "initWithFilter:configuration:delegate:",
            .{ filter, config, delegate },
        );
        break :init id_init;
    };

    const sample_queue = dispatch.queue_create("CaptureStream", dispatch.QUEUE_SERIAL()).?;

    return .{
        .obj = stream,
        .sample_queue = sample_queue,
    };
}

fn drain_queue(_: ?*anyopaque) callconv(.c) void {}
pub fn deinit(self: Self) void {
    self.stopCapture() catch |err| {
        log.err("could not stopCapture: {}", .{err});
    };

    dispatch.sync_f(self.sample_queue, null, drain_queue);
    self.obj.release();
    dispatch.release(self.sample_queue.as_object());
}

pub fn addStreamOutput(self: Self, output: objc.Object) !void {
    try @import("addStreamOutput.zig").addStreamOutput(
        self.obj,
        output,
        OutputType.Screen,
        self.sample_queue,
    );
}

pub fn startCapture(self: Self) !void {
    try @import("startCapture.zig").sync(self.obj);
}

pub fn stopCapture(self: Self) !void {
    try @import("stopCapture.zig").sync(self.obj);
}

pub fn updateConfig(self: Self, cfg: objc.Object) void {
    const NOOP = struct {
        const Block = objc.Block(struct {}, .{objc.c.id}, void);
        fn completed(block: *const Block.Context, err_id: objc.c.id) callconv(.c) void {
            _ = block;
            _ = err_id;
        }
    };

    var block = NOOP.Block.init(.{}, &NOOP.completed);
    self.obj.msgSend(void, "updateConfiguration:completionHandler:", .{ cfg, &block });
}
