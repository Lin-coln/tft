const std = @import("std");
const log = std.log.scoped(.perf);
const Perf = @This();
const Self = Perf;

// 适配新版 API：记录上一次打点的时间戳和 IO 引用
last_mark: std.Io.Timestamp,
name: []const u8,
io: std.Io,

pub fn init(name: []const u8, io: std.Io) Self {
    // 使用 .awake 单调递增时钟，最适合做性能耗时测试
    const now_time = std.Io.Clock.awake.now(io);
    return .{
        .last_mark = now_time,
        .name = name,
        .io = io,
    };
}

pub fn deinit(self: Self) void {
    _ = self;
    // const now_time = std.Io.Clock.awake.now(self.io);
    // const duration = self.last_mark.durationTo(now_time);
    // // 使用 @intCast 将 i96 转换为 u64
    // self.print_time("总计结束", @intCast(duration.toNanoseconds()));
}

pub fn lap(self: *Self, stage_name: []const u8) void { // 注意：这里需要 *Self 指针，因为要修改 last_mark
    const now_time = std.Io.Clock.awake.now(self.io);
    const duration = self.last_mark.durationTo(now_time);
    // 更新时间戳，实现 lap 的“清零/打点”效果
    self.last_mark = now_time;
    // 使用 @intCast 将 i96 转换为 u64
    self.print_time(stage_name, @intCast(duration.toNanoseconds()));
}

pub fn read(self: Self, stage_name: []const u8) void {
    const now_time = std.Io.Clock.awake.now(self.io);
    const duration = self.last_mark.durationTo(now_time);
    // 仅读取，不更新 last_mark
    // 使用 @intCast 将 i96 转换为 u64
    self.print_time(stage_name, @intCast(duration.toNanoseconds()));
}

fn print_time(self: Self, label: []const u8, ns: u64) void {
    const ns_f = @as(f64, @floatFromInt(ns));
    if (ns >= std.time.ns_per_s) {
        log.info("[{s}] {s}: {d:.3} s", .{ self.name, label, ns_f / std.time.ns_per_s });
    } else if (ns >= std.time.ns_per_ms) {
        log.info("[{s}] {s}: {d:.3} ms", .{ self.name, label, ns_f / std.time.ns_per_ms });
    } else if (ns >= std.time.ns_per_us) {
        log.info("[{s}] {s}: {d:.3} µs", .{ self.name, label, ns_f / std.time.ns_per_us });
    } else {
        log.info("[{s}] {s}: {d} ns", .{ self.name, label, ns });
    }
}
