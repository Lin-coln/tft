const std = @import("std");
const cap = @import("capture");

const Packet = cap.Encoder.Packet;

const Self = @This();

allocator: std.mem.Allocator,
items: std.ArrayList(*Packet),
idx_first: usize,
mutex: std.Io.Mutex,

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .items = .empty,
        .idx_first = 0,
        .mutex = .init,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.items.items[self.idx_first..]) |packet| {
        packet.release();
    }
    self.items.deinit(self.allocator);
    self.allocator.destroy(self);
}

pub fn clear(self: *Self) void {
    std.Io.Threaded.mutexLock(&self.mutex);
    defer std.Io.Threaded.mutexUnlock(&self.mutex);

    for (self.items.items[self.idx_first..]) |packet| {
        packet.release();
    }
    self.items.clearRetainingCapacity();
    self.idx_first = 0;
}

pub fn push(self: *Self, borrowed: *Packet) !void {
    const packet = borrowed.retain();
    errdefer packet.release();

    std.Io.Threaded.mutexLock(&self.mutex);
    defer std.Io.Threaded.mutexUnlock(&self.mutex);

    try self.items.append(self.allocator, packet);
}

pub fn shift(self: *Self) ?*Packet {
    std.Io.Threaded.mutexLock(&self.mutex);
    defer std.Io.Threaded.mutexUnlock(&self.mutex);

    if (self.idx_first == self.items.items.len) return null;

    const packet = self.items.items[self.idx_first];
    self.idx_first += 1;
    if (self.idx_first == self.items.items.len) {
        self.items.clearRetainingCapacity();
        self.idx_first = 0;
    }
    return packet;
}
