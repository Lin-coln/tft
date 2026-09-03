const std = @import("std");
const objc = @import("objc");
const Self = @import("Self.zig");

pub const Text = struct {
    observation: usize,
    candidate: usize,
    string: []u8,
    confidence: f32,
};

pub const Results = struct {
    allocator: std.mem.Allocator,
    observation_count: usize,
    items: []Text,

    pub fn deinit(self: Results) void {
        for (self.items) |item| self.allocator.free(item.string);
        self.allocator.free(self.items);
    }
};

pub fn _readResults(self: *Self) !Results {
    const allocator = self.allocator;
    const observations = self.request.getProperty(objc.Object, "results");
    if (observations.value == null) return error.InvalidVisionResult;
    const observation_count = observations.getProperty(usize, "count");

    var items: std.ArrayList(Text) = .empty;
    errdefer {
        for (items.items) |item| allocator.free(item.string);
        items.deinit(allocator);
    }

    var observations_iter = observations.iterate();
    var observation_index: usize = 0;
    while (observations_iter.next()) |observation| : (observation_index += 1) {
        const candidates = observation.msgSend(objc.Object, "topCandidates:", .{self.candidate_count});
        if (candidates.value == null) return error.InvalidVisionResult;

        var candidates_iter = candidates.iterate();
        var candidate_index: usize = 0;
        while (candidates_iter.next()) |candidate| : (candidate_index += 1) {
            const text = try copyCandidate(allocator, candidate, observation_index, candidate_index);
            errdefer allocator.free(text.string);
            try items.append(allocator, text);
        }
    }

    return .{
        .allocator = allocator,
        .observation_count = observation_count,
        .items = try items.toOwnedSlice(allocator),
    };
}

fn copyCandidate(
    allocator: std.mem.Allocator,
    candidate: objc.Object,
    observation_index: usize,
    candidate_index: usize,
) !Text {
    const ns_string = candidate.getProperty(objc.Object, "string");
    if (ns_string.value == null) return error.InvalidVisionResult;
    const utf8 = ns_string.msgSend([*c]const u8, "UTF8String", .{});
    if (utf8 == null) return error.InvalidUTF8String;

    return .{
        .observation = observation_index,
        .candidate = candidate_index,
        .string = try allocator.dupe(u8, std.mem.span(utf8)),
        .confidence = candidate.getProperty(f32, "confidence"),
    };
}

test "Results.deinit releases copied strings" {
    const allocator = std.testing.allocator;
    const items = try allocator.alloc(Text, 1);
    items[0] = .{
        .observation = 0,
        .candidate = 0,
        .string = try allocator.dupe(u8, "霞"),
        .confidence = 1,
    };

    const results = Results{
        .allocator = allocator,
        .observation_count = 1,
        .items = items,
    };
    results.deinit();
}
