//! Full Unicode conformance runner: `zig build conformance`.
//!
//! Runs the whole vendored UCD 16.0.0 corpus through the shared harness and
//! prints a pass/fail table. Enforces a per-suite failure budget so the build
//! fails on regressions; ratchet the budgets down toward zero as the engine
//! improves. Pass `--strict` to require zero failures across every suite.

const std = @import("std");
const conf = @import("conformance.zig");

const GraphemeBreak = @embedFile("testdata/unicode/GraphemeBreakTest.txt");
const WordBreak = @embedFile("testdata/unicode/WordBreakTest.txt");
const Normalization = @embedFile("testdata/unicode/NormalizationTest.txt");
const Emoji = @embedFile("testdata/unicode/emoji-test.txt");
const EastAsianWidth = @embedFile("testdata/unicode/EastAsianWidth.txt");

/// Maximum tolerated failures per suite. Every suite is at full conformance
/// against Unicode 16.0.0, so the budget is zero — CI fails on any regression.
const Budget = struct {
    grapheme: usize,
    word: usize,
    normalization: usize,
    emoji: usize,
    east_asian_width: usize,
};

const budget: Budget = .{
    .grapheme = 0,
    .word = 0,
    .normalization = 0,
    .emoji = 0,
    .east_asian_width = 0,
};

fn printSuite(name: []const u8, report: conf.Report, max_failures: usize) bool {
    const within = report.failed <= max_failures;
    const marker = if (report.failed == 0) "ok " else if (within) "budget" else "FAIL";
    std.debug.print(
        "  {s:<16} {s:<6} {d:>6}/{d:<6} pass  ({d} fail, budget {s})\n",
        .{ name, marker, report.passed, report.total, report.failed, budgetLabel(max_failures) },
    );
    if (report.failed != 0) {
        if (report.first_failure) |f| std.debug.print("      first failure: {s}\n", .{f});
    }
    return within;
}

fn budgetLabel(n: usize) []const u8 {
    return if (n == std.math.maxInt(usize)) "unbounded" else "counted";
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("gcode Unicode 16.0.0 conformance\n", .{});

    var grapheme = conf.runGraphemeBreak(allocator, GraphemeBreak, .{});
    defer grapheme.deinit(allocator);
    var word = conf.runWordBreak(allocator, WordBreak, .{});
    defer word.deinit(allocator);
    var normalization = conf.runNormalization(allocator, Normalization, .{});
    defer normalization.deinit(allocator);
    var emoji = conf.runEmoji(allocator, Emoji, .{});
    defer emoji.deinit(allocator);
    var width = conf.runEastAsianWidth(EastAsianWidth, .{});
    defer width.deinit(allocator);

    const b = budget;

    var all_ok = true;
    all_ok = printSuite("grapheme", grapheme, b.grapheme) and all_ok;
    all_ok = printSuite("word", word, b.word) and all_ok;
    all_ok = printSuite("normalization", normalization, b.normalization) and all_ok;
    all_ok = printSuite("emoji", emoji, b.emoji) and all_ok;
    all_ok = printSuite("east_asian_width", width, b.east_asian_width) and all_ok;

    if (!all_ok) {
        std.debug.print("\nconformance: FAILED (a suite exceeded its failure budget)\n", .{});
        std.process.exit(1);
    }
    std.debug.print("\nconformance: passed (within budgets)\n", .{});
}
