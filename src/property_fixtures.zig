const std = @import("std");
const gcode = @import("lib.zig");

test "invalid UTF-8 fixtures never validate" {
    const invalid_inputs = [_][]const u8{
        &.{0x80},
        &.{ 0xC0, 0xAF },
        &.{ 0xE0, 0x80, 0x80 },
        &.{ 0xF0, 0x80, 0x80, 0x80 },
        &.{ 0xF8, 0x88, 0x80, 0x80, 0x80 },
        &.{ 0xED, 0xA0, 0x80 },
    };

    for (invalid_inputs) |input| {
        try std.testing.expect(!gcode.utf8.validate(input));
    }
}

test "UTF-8 encode/decode round trips valid scalar samples" {
    const samples = [_]u21{ 'A', 'é', '界', '😀', 0x10FFFF };

    for (samples) |cp| {
        var buffer: [4]u8 = undefined;
        const len = try gcode.utf8.encode(cp, &buffer);
        const encoded = buffer[0..len];
        try std.testing.expect(gcode.utf8.validate(encoded));
        try std.testing.expectEqual(cp, try gcode.utf8.decode(encoded));
    }
}

test "normalization idempotence fixtures" {
    const allocator = std.testing.allocator;
    const inputs = [_][]const u8{
        "plain ascii",
        "é",
        "e\u{0301}",
        "Å",
        "①ﬃ",
    };

    inline for (.{ .nfc, .nfd, .nfkc, .nfkd }) |form| {
        for (inputs) |input| {
            const once = try gcode.normalize(allocator, form, input);
            defer allocator.free(once);
            const twice = try gcode.normalize(allocator, form, once);
            defer allocator.free(twice);
            try std.testing.expectEqualStrings(once, twice);
        }
    }
}
