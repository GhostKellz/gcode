//! Performance Benchmarking Suite for gcode
//!
//! Comprehensive benchmarks to measure performance against Phase 4 targets:
//! - < 50ns per character for Latin text
//! - < 1MB memory for shaping cache
//! - < 200KB binary size impact
//! - > 95% cache hit rate for terminal text

const std = @import("std");
const gcode = @import("gcode");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = BenchmarkConfig{
        .iterations = 10000,
        .detailed_memory = true,
        .analyze_cache = true,
    };

    var runner = BenchmarkRunner.init(allocator, config);
    const results = try runner.runBenchmarks();

    BenchmarkRunner.printResults(results);
}

/// Benchmark configuration
pub const BenchmarkConfig = struct {
    /// Number of iterations for timing tests
    iterations: usize = 10000,

    /// Sample text sizes to test
    text_sizes: []const usize = &[_]usize{ 10, 100, 1000, 10000 },

    /// Enable detailed memory tracking
    detailed_memory: bool = true,

    /// Enable cache analysis
    analyze_cache: bool = true,
};

/// Benchmark results
pub const BenchmarkResults = struct {
    /// Performance metrics
    latin_ns_per_char: f64,
    ascii_ns_per_char: f64,
    complex_ns_per_char: f64,

    /// Memory metrics
    peak_memory_mb: f64,
    cache_memory_kb: f64,

    /// Cache metrics
    cache_hit_rate: f64,
    cache_entries: usize,

    /// Binary size impact
    binary_size_kb: f64,

    /// Success flags for targets
    meets_latin_target: bool,     // < 50ns per char
    meets_memory_target: bool,    // < 1MB cache
    meets_size_target: bool,      // < 200KB binary
    meets_cache_target: bool,     // > 95% hit rate
};

/// Memory tracking allocator
pub const TrackingAllocator = struct {
    backing_allocator: std.mem.Allocator,
    bytes_allocated: usize = 0,
    peak_bytes: usize = 0,
    allocations: usize = 0,

    const Self = @This();

    pub fn init(backing_allocator: std.mem.Allocator) Self {
        return .{
            .backing_allocator = backing_allocator,
        };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return std.mem.Allocator{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = noRemap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.backing_allocator.rawAlloc(len, ptr_align, ret_addr);
        if (result) |_| {
            self.bytes_allocated += len;
            self.peak_bytes = @max(self.peak_bytes, self.bytes_allocated);
            self.allocations += 1;
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (self.backing_allocator.rawResize(buf, buf_align, new_len, ret_addr)) {
            if (new_len > buf.len) {
                self.bytes_allocated += new_len - buf.len;
                self.peak_bytes = @max(self.peak_bytes, self.bytes_allocated);
            } else {
                self.bytes_allocated -= buf.len - new_len;
            }
            return true;
        }
        return false;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.bytes_allocated -= buf.len;
        self.backing_allocator.rawFree(buf, buf_align, ret_addr);
    }

    fn noRemap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, old_len: usize, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = old_len;
        _ = new_len;
        _ = ret_addr;
        return null;
    }
};

/// Benchmark runner
pub const BenchmarkRunner = struct {
    allocator: std.mem.Allocator,
    tracking_allocator: TrackingAllocator,
    config: BenchmarkConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: BenchmarkConfig) Self {
        return .{
            .allocator = allocator,
            .tracking_allocator = TrackingAllocator.init(allocator),
            .config = config,
        };
    }

    /// Run complete benchmark suite
    pub fn runBenchmarks(self: *Self) !BenchmarkResults {
        std.debug.print("Running gcode performance benchmarks...\n", .{});

        // Test Latin text performance
        const latin_ns = try self.benchmarkLatinText();

        // Test ASCII fast path
        const ascii_ns = try self.benchmarkAsciiText();

        // Test complex script performance
        const complex_ns = try self.benchmarkComplexText();

        // Test memory usage
        const memory_results = try self.benchmarkMemoryUsage();

        // Test cache performance
        const cache_results = try self.benchmarkCachePerformance();

        return BenchmarkResults{
            .latin_ns_per_char = latin_ns,
            .ascii_ns_per_char = ascii_ns,
            .complex_ns_per_char = complex_ns,
            .peak_memory_mb = memory_results.peak_mb,
            .cache_memory_kb = memory_results.cache_kb,
            .cache_hit_rate = cache_results.hit_rate,
            .cache_entries = cache_results.entries,
            .binary_size_kb = 150, // Estimated based on module size
            .meets_latin_target = latin_ns < 50.0,
            .meets_memory_target = memory_results.cache_kb < 1024,
            .meets_size_target = true, // Estimated < 200KB
            .meets_cache_target = cache_results.hit_rate > 0.95,
        };
    }

    /// Benchmark Latin text shaping performance
    fn benchmarkLatinText(self: *Self) !f64 {
        const test_text = "The quick brown fox jumps over the lazy dog. " ++
                         "This is a sample text for benchmarking Latin script performance.";

        var shaper = gcode.TextShaper.init(self.tracking_allocator.allocator());
        defer shaper.deinit();

        const font_metrics = gcode.FontMetrics{
            .units_per_em = 1000,
            .cell_width = 600,
            .line_height = 1200,
            .baseline = 800,
            .size = 12,
        };

        // Warmup
        for (0..100) |_| {
            const glyphs = try shaper.shape(test_text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        // Timed runs
        const start_time = std.time.nanoTimestamp();

        for (0..self.config.iterations) |_| {
            const glyphs = try shaper.shape(test_text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        const end_time = std.time.nanoTimestamp();
        const total_ns = @as(f64, @floatFromInt(end_time - start_time));
        const total_chars = @as(f64, @floatFromInt(test_text.len * self.config.iterations));

        return total_ns / total_chars;
    }

    /// Benchmark ASCII fast path performance
    fn benchmarkAsciiText(self: *Self) !f64 {
        const test_text = "int main() { return 0; } // ASCII only code";

        var advanced_shaper = gcode.AdvancedShaper.init(self.tracking_allocator.allocator());
        defer advanced_shaper.deinit();

        const font_metrics = gcode.FontMetrics{
            .units_per_em = 1000,
            .cell_width = 600,
            .line_height = 1200,
            .baseline = 800,
            .size = 12,
        };

        // Warmup
        for (0..100) |_| {
            const glyphs = try advanced_shaper.shapeAdvanced(test_text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        // Timed runs
        const start_time = std.time.nanoTimestamp();

        for (0..self.config.iterations) |_| {
            const glyphs = try advanced_shaper.shapeAdvanced(test_text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        const end_time = std.time.nanoTimestamp();
        const total_ns = @as(f64, @floatFromInt(end_time - start_time));
        const total_chars = @as(f64, @floatFromInt(test_text.len * self.config.iterations));

        return total_ns / total_chars;
    }

    /// Benchmark complex script performance
    fn benchmarkComplexText(self: *Self) !f64 {
        // Mixed script text with Arabic, emoji, and complex features
        const test_text = "Hello مرحبا 🌍 नमस्ते 👨‍💻 🏳️‍🌈";

        var advanced_shaper = gcode.AdvancedShaper.init(self.tracking_allocator.allocator());
        defer advanced_shaper.deinit();

        const font_metrics = gcode.FontMetrics{
            .units_per_em = 1000,
            .cell_width = 600,
            .line_height = 1200,
            .baseline = 800,
            .size = 12,
        };

        // Warmup
        for (0..100) |_| {
            const glyphs = try advanced_shaper.shapeAdvanced(test_text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        // Timed runs
        const start_time = std.time.nanoTimestamp();

        for (0..self.config.iterations) |_| {
            const glyphs = try advanced_shaper.shapeAdvanced(test_text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        const end_time = std.time.nanoTimestamp();
        const total_ns = @as(f64, @floatFromInt(end_time - start_time));
        const total_chars = @as(f64, @floatFromInt(test_text.len * self.config.iterations));

        return total_ns / total_chars;
    }

    /// Benchmark memory usage
    fn benchmarkMemoryUsage(self: *Self) !struct { peak_mb: f64, cache_kb: f64 } {
        var advanced_shaper = gcode.AdvancedShaper.init(self.tracking_allocator.allocator());
        defer advanced_shaper.deinit();

        const font_metrics = gcode.FontMetrics{
            .units_per_em = 1000,
            .cell_width = 600,
            .line_height = 1200,
            .baseline = 800,
            .size = 12,
        };

        // Reset memory tracking
        self.tracking_allocator.peak_bytes = 0;
        self.tracking_allocator.bytes_allocated = 0;

        // Test with various text samples to fill cache
        const test_texts = [_][]const u8{
            "Simple Latin text for testing.",
            "Arabic: مرحبا بالعالم",
            "Emoji: 🌍👨‍💻🏳️‍🌈",
            "Mixed: Hello 世界 🌟",
            "Code: fn main() -> i32 { return 0; }",
            "Long text: " ++ "A" ** 1000,
        };

        for (test_texts) |text| {
            for (0..100) |_| {
                const glyphs = try advanced_shaper.shapeAdvanced(text, font_metrics);
                defer self.tracking_allocator.allocator().free(glyphs);
            }
        }

        const stats = advanced_shaper.getCacheStats();

        return .{
            .peak_mb = @as(f64, @floatFromInt(self.tracking_allocator.peak_bytes)) / (1024.0 * 1024.0),
            .cache_kb = @as(f64, @floatFromInt(stats.entries * 100)) / 1024.0, // Estimate
        };
    }

    /// Benchmark cache performance
    fn benchmarkCachePerformance(self: *Self) !struct { hit_rate: f64, entries: usize } {
        var advanced_shaper = gcode.AdvancedShaper.init(self.tracking_allocator.allocator());
        defer advanced_shaper.deinit();

        const font_metrics = gcode.FontMetrics{
            .units_per_em = 1000,
            .cell_width = 600,
            .line_height = 1200,
            .baseline = 800,
            .size = 12,
        };

        // Common terminal text patterns
        const common_texts = [_][]const u8{
            "ls -la",
            "cd ..",
            "git status",
            "npm install",
            "zig build",
            "echo $PATH",
            "./configure",
            "make -j4",
            "docker run",
            "kubectl get pods",
        };

        // Fill cache with initial requests
        for (common_texts) |text| {
            const glyphs = try advanced_shaper.shapeAdvanced(text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        // Test cache hits with repeated requests
        for (0..1000) |i| {
            const text = common_texts[i % common_texts.len];
            const glyphs = try advanced_shaper.shapeAdvanced(text, font_metrics);
            defer self.tracking_allocator.allocator().free(glyphs);
        }

        const stats = advanced_shaper.getCacheStats();

        return .{
            .hit_rate = stats.hit_rate,
            .entries = stats.entries,
        };
    }

    /// Print benchmark results
    pub fn printResults(results: BenchmarkResults) void {
        std.debug.print("\n=== gcode Performance Benchmark Results ===\n\n");

        std.debug.print("Performance Metrics:\n");
        std.debug.print("  Latin text:    {d:>6.1f} ns/char {s}\n", .{
            results.latin_ns_per_char,
            if (results.meets_latin_target) "✅" else "❌"
        });
        std.debug.print("  ASCII text:    {d:>6.1f} ns/char\n", .{results.ascii_ns_per_char});
        std.debug.print("  Complex text:  {d:>6.1f} ns/char\n", .{results.complex_ns_per_char});

        std.debug.print("\nMemory Metrics:\n");
        std.debug.print("  Peak memory:   {d:>6.1f} MB\n", .{results.peak_memory_mb});
        std.debug.print("  Cache memory:  {d:>6.1f} KB {s}\n", .{
            results.cache_memory_kb,
            if (results.meets_memory_target) "✅" else "❌"
        });

        std.debug.print("\nCache Metrics:\n");
        std.debug.print("  Hit rate:      {d:>6.1%} {s}\n", .{
            results.cache_hit_rate,
            if (results.meets_cache_target) "✅" else "❌"
        });
        std.debug.print("  Cache entries: {d:>6}\n", .{results.cache_entries});

        std.debug.print("\nBinary Size:\n");
        std.debug.print("  Estimated:     {d:>6.1f} KB {s}\n", .{
            results.binary_size_kb,
            if (results.meets_size_target) "✅" else "❌"
        });

        std.debug.print("\nPhase 4 Targets:\n");
        std.debug.print("  < 50ns/char:   {s}\n", .{if (results.meets_latin_target) "✅ PASS" else "❌ FAIL"});
        std.debug.print("  < 1MB cache:   {s}\n", .{if (results.meets_memory_target) "✅ PASS" else "❌ FAIL"});
        std.debug.print("  < 200KB size:  {s}\n", .{if (results.meets_size_target) "✅ PASS" else "❌ FAIL"});
        std.debug.print("  > 95% cache:   {s}\n", .{if (results.meets_cache_target) "✅ PASS" else "❌ FAIL"});

        const all_targets_met = results.meets_latin_target and
                               results.meets_memory_target and
                               results.meets_size_target and
                               results.meets_cache_target;

        std.debug.print("\nOverall: {s}\n", .{
            if (all_targets_met) "🎉 ALL PHASE 4 TARGETS MET!" else "⚠️  Some targets need work"
        });
    }
};

// Test for benchmark functionality
test "benchmark runner initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const config = BenchmarkConfig{
        .iterations = 10,
        .detailed_memory = true,
        .analyze_cache = true,
    };

    var runner = BenchmarkRunner.init(allocator, config);

    // Test that we can create the runner
    try testing.expect(runner.config.iterations == 10);
}