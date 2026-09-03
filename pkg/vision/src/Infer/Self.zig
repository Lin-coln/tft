const std = @import("std");
const objc = @import("objc");

const Self = @This();

allocator: std.mem.Allocator,
request: objc.Object,
requests: objc.Object,
candidate_count: usize,

pub const Language = @import("_init_request.zig").Language;
pub const RecognitionLevel = @import("_init_request.zig").RecognitionLevel;
pub const Input = @import("_init_handler.zig").Input;
pub const Region = @import("_set_region_of_interest.zig").Region;
pub const Results = @import("_read_results.zig").Results;

pub const Options = struct {
    allocator: std.mem.Allocator,
    languages: []const Language = &.{ .simplified_chinese, .english_us },
    recognition_level: RecognitionLevel = .accurate,
    uses_language_correction: bool = false,
    minimum_text_height: f32 = 0,
    candidate_count: usize = 3,
};

pub const RunOptions = struct {
    region_of_interest: Region = .full,
};

pub fn init(options: Options) !*Self {
    if (options.candidate_count == 0) return error.InvalidOptions;

    const self = try options.allocator.create(Self);
    errdefer options.allocator.destroy(self);

    self.allocator = options.allocator;
    self.candidate_count = options.candidate_count;
    try @import("_init_request.zig")._initRequest(self, options);
    return self;
}

pub fn deinit(self: *Self) void {
    self.requests.release();
    self.request.release();
    self.allocator.destroy(self);
}

/// Synchronous; do not use the same instance concurrently.
/// Keep input storage alive and unchanged until this call returns.
pub fn run(self: *Self, input: Input, options: RunOptions) !Results {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    try @import("_set_region_of_interest.zig")._setRegionOfInterest(self, options.region_of_interest);

    const handler = try @import("_init_handler.zig")._initHandler(input);
    defer handler.release();

    try @import("_perform_requests.zig")._performRequests(self, handler);
    return @import("_read_results.zig")._readResults(self);
}

test {
    _ = @import("_set_region_of_interest.zig");
    _ = @import("_read_results.zig");
    _ = @import("_tests.zig");
}
