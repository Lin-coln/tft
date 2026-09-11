const std = @import("std");
const objc = @import("objc");

const dispatch = std.c.dispatch;
const Object = objc.Object;
const Callback = *const fn (ctx: ?*anyopaque, data: ?Object, err: ?Object) void;
const Block = objc.Block(
    struct { ctx: ?*anyopaque, callback: usize },
    .{ objc.c.id, objc.c.id },
    void,
);

pub fn getShareableContent(ctx: ?*anyopaque, callback: Callback) void {
    var block = Block.init(
        .{ .ctx = ctx, .callback = @intFromPtr(callback) },
        &completed,
    );
    const Class = objc.getClass("SCShareableContent").?;
    Class.msgSend(void, "getShareableContentWithCompletionHandler:", .{&block});
}

fn completed(
    block: *const Block.Context,
    data_id: objc.c.id,
    err_id: objc.c.id,
) callconv(.c) void {
    const callback: Callback = @ptrFromInt(block.callback);
    callback(
        block.ctx,
        if (data_id != null) Object.fromId(data_id) else null,
        if (err_id != null) Object.fromId(err_id) else null,
    );
}

pub fn retain() !Object {
    const Sync = struct {
        const State = struct {
            semaphore: dispatch.semaphore_t,
            data: ?Object = null,
            failed: bool = false,
        };

        fn completed(ctx: ?*anyopaque, data: ?Object, err: ?Object) void {
            const state: *State = @ptrCast(@alignCast(ctx.?));
            if (err == null) {
                if (data) |value| state.data = value.retain();
            } else {
                state.failed = true;
            }
            _ = dispatch.semaphore_signal(state.semaphore);
        }
    };

    const semaphore = dispatch.semaphore_create(0).?;
    defer dispatch.release(semaphore.as_object());
    var state: Sync.State = .{ .semaphore = semaphore };

    getShareableContent(&state, &Sync.completed);
    _ = dispatch.semaphore_wait(semaphore, .FOREVER);

    if (state.failed) return error.GetShareableContentFailed;
    return state.data orelse error.MissingShareableContent;
}
