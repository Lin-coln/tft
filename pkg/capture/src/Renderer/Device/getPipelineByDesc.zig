const std = @import("std");
const objc = @import("objc");

const Allocator = std.mem.Allocator;

const Self = @import("Self.zig");

pub fn initPipelines(self: *Self) std.AutoHashMap(usize, objc.Object) {
    return std.AutoHashMap(usize, objc.Object).init(self.allocator);
}

pub fn deinitPipelines(self: *Self) void {
    var iter = self.pipelines.valueIterator();
    while (iter.next()) |pipeline| {
        pipeline.*.release();
    }
    self.pipelines.deinit();
}

pub fn getPipelineByDesc(self: *Self, desc: objc.Object) !objc.Object {
    const key = desc.getProperty(usize, "hash");
    if (self.pipelines.get(key)) |pipeline| return pipeline;

    var pipeline_error: objc.c.id = null;
    const pipeline = blk: {
        const value = self.device.msgSend(objc.Object, "newRenderPipelineStateWithDescriptor:error:", .{ desc, &pipeline_error });
        if (value.value == null) return error.PipelineCreationFailed;
        break :blk value;
    };
    errdefer pipeline.release();

    try self.pipelines.put(key, pipeline);
    return pipeline;
}
