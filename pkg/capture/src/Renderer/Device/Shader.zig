const std = @import("std");
const objc = @import("objc");
const foundation = @import("macos").Foundation;

const Allocator = std.mem.Allocator;

const Self = @This();
pub const Type = enum { compute, vertex, pixel };

allocator: Allocator,
library: *objc.Object,
function: *objc.Object,
type: Type,

pub fn create(
    allocator: Allocator,
    device: objc.Object,
    opts: struct {
        source: []const u8,
        name: []const u8,
        type: Type,
    },
) !*Self {
    const autorelease_pool = objc.AutoreleasePool.init();
    defer autorelease_pool.deinit();

    const library_obj = block: {
        const source = try string(opts.source);
        defer source.release();
        var compile_error: objc.c.id = null;
        const result = device.msgSend(objc.Object, "newLibraryWithSource:options:error:", .{
            source, @as(objc.c.id, null), &compile_error,
        });
        if (result.value == null) return error.ShaderCompilationFailed;
        break :block result;
    };
    errdefer library_obj.release();

    const function_obj = block: {
        const name = try string(opts.name);
        defer name.release();
        const result = library_obj.msgSend(objc.Object, "newFunctionWithName:", .{name});
        if (result.value == null) return error.ShaderFunctionMissing;
        break :block result;
    };
    errdefer function_obj.release();

    const library = try allocator.create(objc.Object);
    errdefer allocator.destroy(library);
    library.* = library_obj;

    const function = try allocator.create(objc.Object);
    errdefer allocator.destroy(function);
    function.* = function_obj;

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{
        .allocator = allocator,
        .library = library,
        .function = function,
        .type = opts.type,
    };
    return self;
}

pub fn destroy(self: *Self) void {
    self.function.release();
    self.allocator.destroy(self.function);
    self.library.release();
    self.allocator.destroy(self.library);
    self.allocator.destroy(self);
}

fn string(value: []const u8) !objc.Object {
    const class = objc.getClass("NSString") orelse return error.FoundationUnavailable;
    const allocated = class.msgSend(objc.Object, "alloc", .{});
    const result = allocated.msgSend(
        objc.Object,
        "initWithBytes:length:encoding:",
        .{ value.ptr, value.len, foundation.NSUTF8StringEncoding },
    );
    if (result.value == null) return error.StringCreationFailed;
    return result;
}
