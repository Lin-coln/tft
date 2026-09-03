const std = @import("std");
const objc = @import("objc");

pub const Text = struct {
    observation: usize,
    candidate: usize,
    string: []u8,
    confidence: f32,
};

pub const Results = struct {
    observation_count: usize,
    items: []Text,

    pub fn deinit(self: Results, allocator: std.mem.Allocator) void {
        for (self.items) |item| allocator.free(item.string);
        allocator.free(self.items);
    }
};

pub fn read(allocator: std.mem.Allocator, request: objc.Object) !Results {
    const observations = request.getProperty(objc.Object, "results");
    const observation_count = observations.getProperty(usize, "count");

    var items: std.ArrayList(Text) = .empty;
    errdefer {
        for (items.items) |item| allocator.free(item.string);
        items.deinit(allocator);
    }

    var observation_iterator = observations.iterate();
    var observation_index: usize = 0;
    while (observation_iterator.next()) |observation| : (observation_index += 1) {
        const candidates = observation.msgSend(
            objc.Object,
            "topCandidates:",
            .{@as(usize, 3)},
        );

        var candidate_iterator = candidates.iterate();
        var candidate_index: usize = 0;
        while (candidate_iterator.next()) |candidate| : (candidate_index += 1) {
            const ns_string = candidate.getProperty(objc.Object, "string");
            const utf8 = ns_string.msgSend([*c]const u8, "UTF8String", .{});
            if (utf8 == null) return error.InvalidUTF8String;

            const string = try allocator.dupe(u8, std.mem.span(utf8));
            items.append(allocator, .{
                .observation = observation_index,
                .candidate = candidate_index,
                .string = string,
                .confidence = candidate.getProperty(f32, "confidence"),
            }) catch |err| {
                allocator.free(string);
                return err;
            };
        }
    }

    return .{
        .observation_count = observation_count,
        .items = try items.toOwnedSlice(allocator),
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
        .observation_count = 1,
        .items = items,
    };
    results.deinit(allocator);
}
