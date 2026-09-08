const std = @import("std");
const Frame = @import("../Renderer/Self.zig").Frame;

const SIZE_MAX = 16;
const SIZE_DEF = 6;

const Self = @This();

allocator: std.mem.Allocator,
items: [SIZE_MAX]?*Frame,
size: usize,
size_available: usize,

idx_first: usize,
idx_last: usize,
mutex: std.Io.Mutex,

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.allocator = allocator;
    self.items = @splat(null);
    self.size = SIZE_DEF;
    self.size_available = self.size;
    self.idx_first = 0;
    self.idx_last = 0;
    self.mutex = .init;

    return self;
}

pub fn deinit(self: *Self) void {
    for (self.items[0..self.size]) |item| {
        if (item) |frame| frame.release();
    }
    self.allocator.destroy(self);
}

pub fn count(self: *Self) usize {
    std.Io.Threaded.mutexLock(&self.mutex);
    defer std.Io.Threaded.mutexUnlock(&self.mutex);

    return self.size - self.size_available;
}

pub fn push(self: *Self, frame: *Frame) void {
    std.Io.Threaded.mutexLock(&self.mutex);
    defer std.Io.Threaded.mutexUnlock(&self.mutex);

    if (self.size_available == 0) {
        const last = self.items[self.idx_last].?;
        last.duration_ns = last.duration_ns +| frame.duration_ns;
        last.frame_count = last.frame_count +| frame.frame_count;
        return;
    }

    if (self.size_available != self.size) {
        self.idx_last = init: {
            const raw = self.idx_last + 1;
            const next = if (raw == self.size) 0 else raw;
            break :init next;
        };
    }

    std.debug.assert(self.items[self.idx_last] == null);
    self.size_available -= 1;
    self.items[self.idx_last] = frame.retain();
}

pub fn shift(self: *Self) ?*Frame {
    std.Io.Threaded.mutexLock(&self.mutex);
    defer std.Io.Threaded.mutexUnlock(&self.mutex);

    if (self.size_available == self.size) return null;

    const first = self.items[self.idx_first].?;
    self.items[self.idx_first] = null;

    self.idx_first = init: {
        const raw = self.idx_first + 1;
        const next = if (raw == self.size) 0 else raw;
        break :init next;
    };
    self.size_available += 1;

    if (self.size_available == self.size) {
        self.idx_last = self.idx_first;
    }

    return first;
}
