const std = @import("std");
const objc = @import("objc");

const dispatch = std.c.dispatch;
const Object = objc.Object;

const Callback = *const fn (ctx: ?*anyopaque, err: ?Object) void;

const Block = objc.Block(struct { ctx: ?*anyopaque, callback: usize }, .{objc.c.id}, void);

pub fn startCapture(stream: objc.Object, ctx: ?*anyopaque, callback: Callback) void {
    var block = Block.init(.{ .ctx = ctx, .callback = @intFromPtr(callback) }, &completed);

    stream.msgSend(void, "startCaptureWithCompletionHandler:", .{&block});
}

fn completed(block: *const Block.Context, err_id: objc.c.id) callconv(.c) void {
    const callback: Callback = @ptrFromInt(block.callback);

    callback(
        block.ctx,
        if (err_id != null)
            Object.fromId(err_id)
        else
            null,
    );
}

pub fn sync(stream: objc.Object) !void {
    const Sync = struct {
        const State = struct {
            semaphore: dispatch.semaphore_t,
            failed: bool = false,
        };

        fn completed(ctx: ?*anyopaque, err: ?Object) void {
            const state: *State = @ptrCast(@alignCast(ctx.?));

            if (err != null) {
                state.failed = true;
            }

            _ = dispatch.semaphore_signal(state.semaphore);
        }
    };

    const semaphore = dispatch.semaphore_create(0).?;
    defer dispatch.release(semaphore.as_object());
    var state: Sync.State = .{ .semaphore = semaphore };

    startCapture(stream, &state, &Sync.completed);

    _ = dispatch.semaphore_wait(semaphore, .FOREVER);

    if (state.failed) return error.StartCaptureFailed;
}
