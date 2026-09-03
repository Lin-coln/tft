const std = @import("std");
const objc = @import("objc");

const OutputType = @import("Self.zig").OutputType;

const dispatch = std.c.dispatch;

pub fn addStreamOutput(
    stream: objc.Object,
    output: objc.Object,
    output_type: OutputType,
    sample_queue: dispatch.queue_t,
) !void {
    var output_error: objc.c.id = null;

    const added = stream.msgSend(
        bool,
        "addStreamOutput:type:sampleHandlerQueue:error:",
        .{
            output,
            @intFromEnum(output_type),
            sample_queue,
            &output_error,
        },
    );

    if (!added) {
        return error.AddStreamOutputFailed;
    }
}
