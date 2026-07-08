//! Shared Unicode conformance harness.
//!
//! One parser for the official UCD fixture formats, used by both the full
//! `conformance` executable (whole files) and the quick `zig build test`
//! subset. The fixtures live under `testdata/unicode/` and are the vendored,
//! checksum-pinned upstream files (see that directory's README).
//!
//! Every runner returns a `Report` of pass/fail counts plus the first failing
//! case, so callers can enforce a failure budget instead of aborting on the
//! first mismatch. Nothing here prints — that is the caller's job.

const std = @import("std");
const gcode = @import("gcode");

pub const Report = struct {
    total: usize = 0,
    passed: usize = 0,
    failed: usize = 0,
    /// Human-readable description of the first failing case, owned by the
    /// report. `null` when everything passed.
    first_failure: ?[]u8 = null,

    fn record(self: *Report, allocator: ?std.mem.Allocator, ok: bool, line: []const u8) void {
        self.total += 1;
        if (ok) {
            self.passed += 1;
        } else {
            self.failed += 1;
            if (self.first_failure == null) {
                if (allocator) |a| self.first_failure = a.dupe(u8, std.mem.trim(u8, line, " \t\r")) catch null;
            }
        }
    }

    pub fn deinit(self: *Report, allocator: std.mem.Allocator) void {
        if (self.first_failure) |f| allocator.free(f);
        self.first_failure = null;
    }
};

pub const Options = struct {
    /// Stop after this many parsed cases (0 = run the whole file). Used to keep
    /// `zig build test` fast while the executable runs the full corpus.
    limit: usize = 0,
};

fn appendCodepointUtf8(allocator: std.mem.Allocator, out: *std.ArrayList(u8), cp_hex: []const u8) !void {
    const cp = try std.fmt.parseInt(u21, cp_hex, 16);
    var buf: [4]u8 = undefined;
    const len = try std.unicode.utf8Encode(cp, &buf);
    try out.appendSlice(allocator, buf[0..len]);
}

fn decodeHexSequence(allocator: std.mem.Allocator, hex_sequence: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var tokens = std.mem.tokenizeScalar(u8, hex_sequence, ' ');
    while (tokens.next()) |token| try appendCodepointUtf8(allocator, &out, token);
    return out.toOwnedSlice(allocator);
}

const ParsedBoundary = struct { text: []u8, clusters: [][]const u8 };

/// Parse a UAX #29 boundary line: `÷ 0061 × 0301 ÷ 0062 ÷`.
/// `÷` marks a boundary, `×` marks a non-boundary. Returns the decoded UTF-8
/// text plus the expected segments between boundaries. Caller frees both.
fn parseBoundaryLine(allocator: std.mem.Allocator, line_raw: []const u8) !?ParsedBoundary {
    const line_no_comment = if (std.mem.indexOfScalar(u8, line_raw, '#')) |idx| line_raw[0..idx] else line_raw;
    const trimmed = std.mem.trim(u8, line_no_comment, " \t\r");
    if (trimmed.len == 0) return null;

    var tokens = std.mem.tokenizeAny(u8, trimmed, " \t\r\n");
    var text: std.ArrayList(u8) = .empty;
    errdefer text.deinit(allocator);
    var starts: std.ArrayList(usize) = .empty;
    defer starts.deinit(allocator);
    try starts.append(allocator, 0);

    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, "÷")) {
            const end = text.items.len;
            if (starts.items[starts.items.len - 1] != end) try starts.append(allocator, end);
        } else if (std.mem.eql(u8, token, "×")) {
            continue;
        } else {
            try appendCodepointUtf8(allocator, &text, token);
        }
    }

    const owned_text = try text.toOwnedSlice(allocator);
    errdefer allocator.free(owned_text);
    if (owned_text.len == 0) return null;
    if (starts.items[starts.items.len - 1] != owned_text.len) try starts.append(allocator, owned_text.len);

    const clusters = try allocator.alloc([]const u8, starts.items.len - 1);
    for (clusters, 0..) |*cluster, i| {
        cluster.* = owned_text[starts.items[i]..starts.items[i + 1]];
    }
    return .{ .text = owned_text, .clusters = clusters };
}

const BoundaryKind = enum { grapheme, word };

fn segmentsMatch(comptime kind: BoundaryKind, input: []const u8, expected: []const []const u8) bool {
    var iter = switch (kind) {
        .grapheme => gcode.graphemeIterator(input),
        .word => gcode.wordIterator(input),
    };
    for (expected) |want| {
        const got = iter.next() orelse return false;
        if (!std.mem.eql(u8, want, got)) return false;
    }
    return iter.next() == null;
}

fn runBoundary(comptime kind: BoundaryKind, allocator: std.mem.Allocator, content: []const u8, opts: Options) Report {
    var report: Report = .{};
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const parsed = (parseBoundaryLine(allocator, line) catch continue) orelse continue;
        defer allocator.free(parsed.text);
        defer allocator.free(parsed.clusters);
        report.record(allocator, segmentsMatch(kind, parsed.text, parsed.clusters), line);
        if (opts.limit != 0 and report.total >= opts.limit) break;
    }
    return report;
}

pub fn runGraphemeBreak(allocator: std.mem.Allocator, content: []const u8, opts: Options) Report {
    return runBoundary(.grapheme, allocator, content, opts);
}

pub fn runWordBreak(allocator: std.mem.Allocator, content: []const u8, opts: Options) Report {
    return runBoundary(.word, allocator, content, opts);
}

/// NormalizationTest.txt: `source; NFC; NFD; NFKC; NFKD; # comment`.
/// `@Part` section headers and comments are skipped. A case passes only when
/// all four forms of `source` match their expected columns.
pub fn runNormalization(allocator: std.mem.Allocator, content: []const u8, opts: Options) Report {
    var report: Report = .{};
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = if (std.mem.indexOfScalar(u8, line_raw, '#')) |idx| line_raw[0..idx] else line_raw;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "@")) continue;

        var fields = std.mem.splitScalar(u8, trimmed, ';');
        const source = decodeHexSequence(allocator, std.mem.trim(u8, fields.next() orelse continue, " \t")) catch continue;
        defer allocator.free(source);
        const cols = blk: {
            var out: [4][]u8 = undefined;
            var n: usize = 0;
            while (n < 4) : (n += 1) {
                const field = fields.next() orelse break;
                out[n] = decodeHexSequence(allocator, std.mem.trim(u8, field, " \t")) catch break;
            }
            break :blk .{ .vals = out, .n = n };
        };
        defer for (0..cols.n) |i| allocator.free(cols.vals[i]);
        if (cols.n < 4) continue;

        const forms = [4]gcode.NormalizationForm{ .nfc, .nfd, .nfkc, .nfkd };
        var ok = true;
        for (forms, 0..) |form, i| {
            const got = gcode.normalize(allocator, form, source) catch {
                ok = false;
                break;
            };
            defer allocator.free(got);
            if (!std.mem.eql(u8, cols.vals[i], got)) {
                ok = false;
                break;
            }
        }
        report.record(allocator, ok, line);
        if (opts.limit != 0 and report.total >= opts.limit) break;
    }
    return report;
}

/// emoji-test.txt: `1F469 200D 1F4BB ; fully-qualified # 👩‍💻 ...`.
/// Each fully-qualified sequence must form exactly one grapheme cluster — a
/// direct test of terminal emoji clustering (ZWJ, modifiers, keycaps, flags).
pub fn runEmoji(allocator: std.mem.Allocator, content: []const u8, opts: Options) Report {
    var report: Report = .{};
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const semi = std.mem.indexOfScalar(u8, line_raw, ';') orelse continue;
        const hex = std.mem.trim(u8, line_raw[0..semi], " \t\r");
        if (hex.len == 0) continue;
        const rest = line_raw[semi + 1 ..];
        const status_end = std.mem.indexOfScalar(u8, rest, '#') orelse rest.len;
        const status = std.mem.trim(u8, rest[0..status_end], " \t\r");
        if (!std.mem.eql(u8, status, "fully-qualified")) continue;

        const text = decodeHexSequence(allocator, hex) catch continue;
        defer allocator.free(text);
        var iter = gcode.graphemeIterator(text);
        const first = iter.next();
        const single = first != null and std.mem.eql(u8, first.?, text) and iter.next() == null;
        report.record(allocator, single, line_raw);
        if (opts.limit != 0 and report.total >= opts.limit) break;
    }
    return report;
}

/// EastAsianWidth.txt: `RANGE; CLASS`. Validates the generated width table
/// against the property file under both ambiguous-width policies.
pub fn runEastAsianWidth(content: []const u8, opts: Options) Report {
    var report: Report = .{};
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = if (std.mem.indexOfScalar(u8, line_raw, '#')) |idx| line_raw[0..idx] else line_raw;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        const semi = std.mem.indexOfScalar(u8, trimmed, ';') orelse continue;
        const range_part = std.mem.trim(u8, trimmed[0..semi], " \t");
        const class_part = std.mem.trim(u8, trimmed[semi + 1 ..], " \t");

        const lo: u21, const hi: u21 = if (std.mem.indexOf(u8, range_part, "..")) |dots| .{
            std.fmt.parseInt(u21, range_part[0..dots], 16) catch continue,
            std.fmt.parseInt(u21, range_part[dots + 2 ..], 16) catch continue,
        } else blk: {
            const v = std.fmt.parseInt(u21, range_part, 16) catch continue;
            break :blk .{ v, v };
        };

        // Sample the endpoints rather than every codepoint in huge ranges.
        const probes = [_]u21{ lo, hi, lo +| ((hi - lo) / 2) };
        var ok = true;
        for (probes) |cp| {
            if (cp > 0x10FFFF) continue;
            const zero_width = gcode.getWidth(cp) == 0;
            const wide_class = std.mem.eql(u8, class_part, "W") or std.mem.eql(u8, class_part, "F");
            const ambiguous_class = std.mem.eql(u8, class_part, "A");
            const props = gcode.getProperties(cp);
            const expect_narrow: u2 = if (zero_width) 0 else if (wide_class) 2 else 1;
            const expect_wide: u2 = if (zero_width) 0 else if (wide_class or ambiguous_class or props.ambiguous_width) 2 else 1;
            if (gcode.getWidthWithPolicy(cp, .narrow) != expect_narrow or
                gcode.getWidthWithPolicy(cp, .wide) != expect_wide)
            {
                ok = false;
                break;
            }
        }
        report.record(null, ok, trimmed);
        if (opts.limit != 0 and report.total >= opts.limit) break;
    }
    return report;
}
