const std = @import("std");
const objc = @import("objc");
const macos = @import("macos");

const ptc = @import("objc-protocol.zig");

const cm = macos.CoreMedia;

const Self = @import("Self.zig");

pub fn _init_delegate(self: *Self) void {
    const obj = init: {
        const id_alloc = getClass().msgSend(objc.Object, "alloc", .{});
        const id_init = id_alloc.msgSend(objc.Object, "init", .{});
        break :init id_init;
    };

    Binding.set(obj, self);

    self.delegate = obj;
}

pub fn _deinit_delegate(self: *Self) void {
    Binding.set(self.delegate, null);
    self.delegate.release();
}

///////////////////////////////////////////////////////////////////////////////////////////////

const Binding = ptc.bindVar("binding", Self);

const getClass = ptc.defineClass("CaptureStreamDelegate", handle_bind);

fn handle_bind(Class: objc.Class) void {
    Binding.define(Class);

    ptc.addProtocol(Class, "SCStreamDelegate");
    ptc.addProtocol(Class, "SCStreamOutput");

    ptc.addMethod(
        Class,
        "stream:didStopWithError:",
        handle_stream_didStopWithError,
    );
    ptc.addMethod(
        Class,
        "stream:didOutputSampleBuffer:ofType:",
        handle_stream_didOutputSampleBuffer,
    );
}

fn handle_stream_didStopWithError(
    delegate_id: objc.c.id,
    _: objc.c.SEL,
    stream_id: objc.c.id,
    err_id: objc.c.id,
) callconv(.c) void {
    const self = Binding.get(delegate_id) orelse return;
    _ = stream_id;

    if (err_id == null) return;
    const err = objc.Object.fromId(err_id).retain();
    std.Io.Threaded.mutexLock(&self.err_mutex);
    @import("_update_err.zig")._update(self, err);
    std.Io.Threaded.mutexUnlock(&self.err_mutex);
}

fn handle_stream_didOutputSampleBuffer(
    delegate_id: objc.c.id,
    _: objc.c.SEL,
    stream_id: objc.c.id,
    buffer: cm.CMSampleBufferRef,
    output_type: c_long,
) callconv(.c) void {
    const self = Binding.get(delegate_id) orelse return;
    _ = stream_id;
    _ = output_type;

    std.Io.Threaded.mutexLock(&self.output_mutex);
    @import("_update_frame.zig")._updateFromSampleBuffer(self, buffer);
    @import("_update_surface.zig")._updateFromSampleBuffer(self, buffer);
    std.Io.Threaded.mutexUnlock(&self.output_mutex);
}
