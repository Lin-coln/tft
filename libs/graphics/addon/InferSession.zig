const std = @import("std");
const cap = @import("capture");
const Infer = @import("vision").Infer;

const Capture = cap.Capture;
const dispatch = std.c.dispatch;
const log = std.log.scoped(.infer_session);
const Self = @This();

thread: std.Thread,
worker: *Worker,

pub const Options = struct {
    /// Must allow allocation/free from different threads.
    allocator: std.mem.Allocator,
    /// Borrowed. Destroy the session before destroying Capture.
    capture: *Capture,
};

pub fn init(options: Options) !Self {
    const worker = try options.allocator.create(Worker);
    errdefer options.allocator.destroy(worker);

    worker.* = .{
        .allocator = options.allocator,
        .capture = options.capture,
        .infer = try Infer.init(.{ .allocator = options.allocator }),
        .wake = undefined,
        .stopping = .init(false),
    };
    errdefer worker.infer.deinit();

    worker.wake = dispatch.semaphore_create(0) orelse return error.SemaphoreCreationFailed;
    errdefer dispatch.release(worker.wake.as_object());

    return .{
        .thread = try std.Thread.spawn(.{}, run, .{worker}),
        .worker = worker,
    };
}

/// Joins any in-flight inference. Call once; do not copy ownership of the session.
pub fn deinit(self: Self) void {
    self.worker.stopping.store(true, .release);
    _ = dispatch.semaphore_signal(self.worker.wake);
    self.thread.join();
    dispatch.release(self.worker.wake.as_object());
    self.worker.infer.deinit();
    self.worker.allocator.destroy(self.worker);
}

// Only this heap allocation is referenced by the thread. The containing
// Screenshot/InferSession values may move during construction and N-API wrapping.
const Worker = struct {
    allocator: std.mem.Allocator,
    capture: *Capture,
    infer: *Infer,
    wake: dispatch.semaphore_t,
    stopping: std.atomic.Value(bool),
};

fn run(worker: *Worker) void {
    while (!worker.stopping.load(.acquire)) {
        // One latest-frame inference every 3 seconds, measured start-to-start.
        // Slow inference does not queue frames or cause catch-up bursts.
        const deadline = dispatch.time(.NOW, 3 * std.time.ns_per_s);
        inferLatest(worker) catch |err| {
            log.err("inference failed: {s}", .{@errorName(err)});
        };
        if (worker.stopping.load(.acquire)) break;
        _ = dispatch.semaphore_wait(worker.wake, deadline);
    }
}

fn inferLatest(worker: *Worker) !void {
    const surface = worker.capture.get_surface() orelse return;
    defer surface.deinit();

    const results = try worker.infer.run(.{ .io_surface = surface.ref }, .{});
    defer results.deinit();

    if (results.items.len == 0) {
        log.info("no text recognized", .{});
        return;
    }
    for (results.items) |item| {
        log.info("observation[{d}] candidate[{d}]: text=\"{s}\" confidence={d:.4}", .{
            item.observation, item.candidate, item.string, item.confidence,
        });
    }
}

test "session value can move and stop without a surface" {
    var capture: Capture = undefined;
    capture.output_mutex = .init;
    capture.surface = null;

    const session = try Self.init(.{ .allocator = std.testing.allocator, .capture = &capture });
    // Put the returned value in another owner, as Screenshot.init does.
    const owner = struct { session: Self }{ .session = session };
    const io = std.Io.Threaded.global_single_threaded.io();
    const start = std.Io.Clock.awake.now(io);
    owner.session.deinit();
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io));
    try std.testing.expect(elapsed.toMilliseconds() < 2000);
}

test "allocation failures clean up the session and infer instance" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, initAndDeinit, .{});
}

fn initAndDeinit(allocator: std.mem.Allocator) !void {
    var capture: Capture = undefined;
    capture.output_mutex = .init;
    capture.surface = null;
    const session = try Self.init(.{ .allocator = allocator, .capture = &capture });
    session.deinit();
}
