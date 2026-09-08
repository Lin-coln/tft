const std = @import("std");
const macos = @import("macos");
const Frame = @import("../Renderer/Frame.zig");

const cf = macos.CoreFoundation;
const cm = macos.CoreMedia;
const vt = macos.VideoToolbox;

const Self = @This();
pub const log = std.log.scoped(.encoder);
pub const Config = @import("configure.zig").Config;
pub const Packet = @import("Packet.zig");
pub const ResolveConfig = @import("ResolveConfig.zig");
pub const Options = struct {
    ctx: *anyopaque,
    handle_error: *const fn (ctx: *anyopaque, err: anyerror) void,
    handle_output: *const fn (
        ctx: *anyopaque,
        borrowed: *Frame,
        sample_buffer: cm.CMSampleBufferRef,
    ) anyerror!void,
};

allocator: std.mem.Allocator,
session: ?vt.VTCompressionSessionRef,
cfg: ?Config,
cfg_resolved: ?*ResolveConfig,
cfg_resolved_mutex: std.Io.Mutex,

ctx: *anyopaque,
handle_error: *const fn (ctx: *anyopaque, err: anyerror) void,
handle_output: *const fn (
    ctx: *anyopaque,
    borrowed: *Frame,
    sample_buffer: cm.CMSampleBufferRef,
) anyerror!void,

pub const configure = @import("configure.zig").configure;
pub const encode = @import("encode.zig").encode;
pub fn init(allocator: std.mem.Allocator, opts: Options) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .session = null,
        .ctx = opts.ctx,
        .cfg = null,
        .cfg_resolved = null,
        .cfg_resolved_mutex = .init,
        .handle_error = opts.handle_error,
        .handle_output = opts.handle_output,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    if (self.session) |session| {
        self.session = null;

        _ = vt.VTCompressionSessionCompleteFrames(session, cm.kCMTimeInvalid);
        vt.VTCompressionSessionInvalidate(session);
        cf.CFRelease(@ptrCast(session));
    }

    if (self.cfg_resolved) |cfg| cfg.release();
    self.allocator.destroy(self);
}

pub fn getResolvedConfig(self: *Self) ?*ResolveConfig {
    std.Io.Threaded.mutexLock(&self.cfg_resolved_mutex);
    defer std.Io.Threaded.mutexUnlock(&self.cfg_resolved_mutex);

    const cfg = self.cfg_resolved orelse return null;
    return cfg.retain();
}
