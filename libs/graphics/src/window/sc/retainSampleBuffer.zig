const std = @import("std");
const objc = @import("objc");

const dispatch = std.c.dispatch;

const Completion = objc.Block(
    struct { result: *objc.c.id, semaphore: dispatch.semaphore_t },
    .{ objc.c.id, objc.c.id },
    void,
);

pub fn retainSampleBuffer(filter: objc.Object, config: objc.Object) ?objc.Object {
    const semaphore = dispatch.semaphore_create(0) orelse return null;
    defer dispatch.release(semaphore.as_object());

    var sample_buffer_id: objc.c.id = null;
    const manager = objc.getClass("SCScreenshotManager") orelse return null;
    var completion = Completion.init(
        .{ .result = &sample_buffer_id, .semaphore = semaphore },
        callback,
    );

    dispatch.retain(semaphore.as_object());
    manager.msgSend(void, "captureSampleBufferWithFilter:configuration:completionHandler:", .{
        filter,
        config,
        &completion,
    });
    _ = dispatch.semaphore_wait(semaphore, .FOREVER);

    if (sample_buffer_id == null) return null;
    return objc.Object.fromId(sample_buffer_id);
}

fn callback(
    completion: *const Completion.Context,
    sample_buffer_id: objc.c.id,
    error_value: objc.c.id,
) callconv(.c) void {
    if (error_value == null) {
        if (sample_buffer_id) |id| {
            const sample_buffer = objc.Object.fromId(id);
            completion.result.* = sample_buffer.retain().value;
        }
    } else {
        // log_ns_error("failed to getShareableContent", error_value);
    }
    _ = dispatch.semaphore_signal(completion.semaphore);
    dispatch.release(completion.semaphore.as_object());
}
