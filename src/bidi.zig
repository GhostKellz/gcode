//! BiDi (Bidirectional) Algorithm Implementation
//!
//! Implements Unicode Standard Annex #9: Unicode Bidirectional Algorithm
//! For terminal emulators and text processing requiring RTL language support.
//!
//! This is critical for enabling zfont to properly shape Arabic, Hebrew, and
//! other RTL scripts in Ghostshell.

const std = @import("std");
const props = @import("properties.zig");

/// BiDi class for UAX #9 (Bidirectional Algorithm)
pub const BiDiClass = enum(u5) {
    L,   // Left-to-Right
    R,   // Right-to-Left
    AL,  // Right-to-Left Arabic
    EN,  // European Number
    ES,  // European Number Separator
    ET,  // European Number Terminator
    AN,  // Arabic Number
    CS,  // Common Number Separator
    NSM, // Nonspacing Mark
    BN,  // Boundary Neutral
    B,   // Paragraph Separator
    S,   // Segment Separator
    WS,  // Whitespace
    ON,  // Other Neutrals
    LRE, // Left-to-Right Embedding
    LRO, // Left-to-Right Override
    RLE, // Right-to-Left Embedding
    RLO, // Right-to-Left Override
    PDF, // Pop Directional Format
    LRI, // Left-to-Right Isolate
    RLI, // Right-to-Left Isolate
    FSI, // First Strong Isolate
    PDI, // Pop Directional Isolate

    /// Returns true if this is a strong directional character
    pub fn isStrong(self: BiDiClass) bool {
        return switch (self) {
            .L, .R, .AL => true,
            else => false,
        };
    }

    /// Returns true if this is a neutral character
    pub fn isNeutral(self: BiDiClass) bool {
        return switch (self) {
            .B, .S, .WS, .ON => true,
            else => false,
        };
    }

    /// Returns true if this is an RTL character
    pub fn isRTL(self: BiDiClass) bool {
        return switch (self) {
            .R, .AL => true,
            else => false,
        };
    }

    /// Returns true if this is an isolate initiator
    pub fn isIsolateInitiator(self: BiDiClass) bool {
        return switch (self) {
            .LRI, .RLI, .FSI => true,
            else => false,
        };
    }
};

/// Direction for text flow
pub const Direction = enum(u1) {
    LTR = 0, // Left-to-Right
    RTL = 1, // Right-to-Left
};

/// BiDi level (embedding level) - even = LTR, odd = RTL
pub const Level = u8;

/// Maximum embedding level according to UAX #9
pub const MAX_DEPTH: u8 = 125;

/// BiDi run - a sequence of characters with the same embedding level
pub const Run = struct {
    start: usize,    // Start index in text
    length: usize,   // Length of run
    level: Level,    // Embedding level
    direction: Direction,

    pub fn end(self: Run) usize {
        return self.start + self.length;
    }

    pub fn isRTL(self: Run) bool {
        return self.level % 2 == 1;
    }
};

/// BiDi algorithm state for processing text
pub const BiDiContext = struct {
    /// Paragraph base direction
    base_direction: Direction = .LTR,

    /// Stack for tracking embedding levels
    level_stack: std.ArrayList(Level),

    /// Current embedding level
    current_level: Level = 0,

    /// Isolate run stack
    isolate_stack: std.ArrayList(usize),

    /// Override status
    override_status: enum { none, ltr, rtl } = .none,

    /// Allocator for dynamic arrays
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .level_stack = std.ArrayList(Level){},
            .isolate_stack = std.ArrayList(usize){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.level_stack.deinit(self.allocator);
        self.isolate_stack.deinit(self.allocator);
    }

    pub fn reset(self: *Self, base_dir: Direction) void {
        self.base_direction = base_dir;
        self.current_level = if (base_dir == .RTL) @as(Level, 1) else @as(Level, 0);
        self.level_stack.clearRetainingCapacity();
        self.isolate_stack.clearRetainingCapacity();
        self.override_status = .none;
    }
};

/// BiDi algorithm implementation
pub const BiDi = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Determines the base direction of a paragraph
    /// Rule P2: Find the first strong character and use its direction
    pub fn getBaseDirection(self: Self, text: []const u32) Direction {
        _ = self;
        for (text) |cp| {
            const bidi_class = getBiDiClass(cp);
            switch (bidi_class) {
                .L => return .LTR,
                .R, .AL => return .RTL,
                else => continue,
            }
        }
        return .LTR; // Default to LTR if no strong character found
    }

    /// Process text with BiDi algorithm and return runs
    pub fn processText(
        self: Self,
        text: []const u32,
        base_dir: Direction,
    ) ![]Run {
        var context = BiDiContext.init(self.allocator);
        defer context.deinit();

        context.reset(base_dir);

        // Step 1: Determine character types (already done via getBiDiClass)

        // Step 2: Resolve explicit formatting characters
        const levels = try self.allocator.alloc(Level, text.len);
        defer self.allocator.free(levels);

        try self.resolveExplicitLevels(text, &context, levels);

        // Step 3: Resolve weak types
        try self.resolveWeakTypes(text, levels);

        // Step 4: Resolve neutral types
        try self.resolveNeutralTypes(text, levels);

        // Step 5: Resolve implicit levels
        self.resolveImplicitLevels(text, levels);

        // Step 6: Create runs from levels
        return self.createRuns(levels);
    }

    /// Resolve explicit formatting characters (Rules X1-X10)
    fn resolveExplicitLevels(
        self: Self,
        text: []const u32,
        context: *BiDiContext,
        levels: []Level,
    ) !void {
        _ = self;

        for (text, 0..) |cp, i| {
            const bidi_class = getBiDiClass(cp);

            switch (bidi_class) {
                .LRE => {
                    // Left-to-Right Embedding
                    const new_level = (context.current_level + 2) & ~@as(Level, 1);
                    if (new_level <= MAX_DEPTH) {
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                    }
                    levels[i] = context.current_level;
                },
                .RLE => {
                    // Right-to-Left Embedding
                    const new_level = (context.current_level + 1) | 1;
                    if (new_level <= MAX_DEPTH) {
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                    }
                    levels[i] = context.current_level;
                },
                .LRO => {
                    // Left-to-Right Override
                    const new_level = (context.current_level + 2) & ~@as(Level, 1);
                    if (new_level <= MAX_DEPTH) {
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                        context.override_status = .ltr;
                    }
                    levels[i] = context.current_level;
                },
                .RLO => {
                    // Right-to-Left Override
                    const new_level = (context.current_level + 1) | 1;
                    if (new_level <= MAX_DEPTH) {
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                        context.override_status = .rtl;
                    }
                    levels[i] = context.current_level;
                },
                .PDF => {
                    // Pop Directional Format
                    if (context.level_stack.items.len > 0) {
                        context.current_level = context.level_stack.pop().?;
                        context.override_status = .none;
                    }
                    levels[i] = context.current_level;
                },
                .LRI => {
                    // Left-to-Right Isolate
                    const new_level = (context.current_level + 2) & ~@as(Level, 1);
                    if (new_level <= MAX_DEPTH) {
                        try context.isolate_stack.append(context.allocator, i);
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                    }
                    levels[i] = context.current_level;
                },
                .RLI => {
                    // Right-to-Left Isolate
                    const new_level = (context.current_level + 1) | 1;
                    if (new_level <= MAX_DEPTH) {
                        try context.isolate_stack.append(context.allocator, i);
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                    }
                    levels[i] = context.current_level;
                },
                .FSI => {
                    // First Strong Isolate - determine direction from following text
                    var dir: Direction = .LTR;
                    for (text[i + 1 ..]) |next_cp| {
                        const next_class = getBiDiClass(next_cp);
                        if (next_class.isStrong()) {
                            dir = if (next_class.isRTL()) .RTL else .LTR;
                            break;
                        }
                    }

                    const new_level = if (dir == .RTL)
                        (context.current_level + 1) | 1
                    else
                        (context.current_level + 2) & ~@as(Level, 1);

                    if (new_level <= MAX_DEPTH) {
                        try context.isolate_stack.append(context.allocator, i);
                        try context.level_stack.append(context.allocator, context.current_level);
                        context.current_level = new_level;
                    }
                    levels[i] = context.current_level;
                },
                .PDI => {
                    // Pop Directional Isolate
                    if (context.isolate_stack.items.len > 0) {
                        _ = context.isolate_stack.pop();
                        if (context.level_stack.items.len > 0) {
                            context.current_level = context.level_stack.pop().?;
                        }
                    }
                    levels[i] = context.current_level;
                },
                else => {
                    levels[i] = context.current_level;
                },
            }
        }
    }

    /// Resolve weak types (Rules W1-W7)
    fn resolveWeakTypes(self: Self, text: []const u32, levels: []Level) !void {
        _ = self;
        _ = text;
        _ = levels;
        // TODO: Implement weak type resolution
        // This handles European numbers, Arabic numbers, separators, etc.
    }

    /// Resolve neutral types (Rules N1-N2)
    fn resolveNeutralTypes(self: Self, text: []const u32, levels: []Level) !void {
        _ = self;
        _ = text;
        _ = levels;
        // TODO: Implement neutral type resolution
        // This handles whitespace, punctuation, symbols, etc.
    }

    /// Resolve implicit levels (Rules I1-I2)
    fn resolveImplicitLevels(self: Self, text: []const u32, levels: []Level) void {
        _ = self;

        for (text, 0..) |cp, i| {
            const bidi_class = getBiDiClass(cp);
            const level = levels[i];

            // Rule I1: For all characters with an even (LTR) embedding level
            if (level % 2 == 0) {
                if (bidi_class.isRTL()) {
                    levels[i] = level + 1;
                }
            } else {
                // Rule I2: For all characters with an odd (RTL) embedding level
                if (bidi_class == .L or bidi_class == .EN) {
                    levels[i] = level + 1;
                }
            }
        }
    }

    /// Create runs from resolved levels
    fn createRuns(self: Self, levels: []const Level) ![]Run {
        var runs = std.ArrayList(Run){};
        defer runs.deinit(self.allocator);

        if (levels.len == 0) {
            return try self.allocator.dupe(Run, &[_]Run{});
        }

        var start: usize = 0;
        var current_level = levels[0];

        for (levels[1..], 1..) |level, i| {
            if (level != current_level) {
                // End of current run
                const direction: Direction = if (current_level % 2 == 1) .RTL else .LTR;
                try runs.append(self.allocator, Run{
                    .start = start,
                    .length = i - start,
                    .level = current_level,
                    .direction = direction,
                });

                start = i;
                current_level = level;
            }
        }

        // Add final run
        const direction: Direction = if (current_level % 2 == 1) .RTL else .LTR;
        try runs.append(self.allocator, Run{
            .start = start,
            .length = levels.len - start,
            .level = current_level,
            .direction = direction,
        });

        return try self.allocator.dupe(Run, runs.items);
    }
};

/// Get BiDi class for a codepoint (placeholder - would use lookup table)
pub fn getBiDiClass(cp: u32) BiDiClass {
    // Simplified classification for now
    // In the full implementation, this would use the generated lookup tables

    if (cp >= 0x0041 and cp <= 0x005A) return .L; // A-Z
    if (cp >= 0x0061 and cp <= 0x007A) return .L; // a-z
    if (cp >= 0x05D0 and cp <= 0x05EA) return .R; // Hebrew
    if (cp >= 0x0600 and cp <= 0x06FF) return .AL; // Arabic
    if (cp >= 0x0030 and cp <= 0x0039) return .EN; // 0-9
    if (cp == 0x0020) return .WS; // Space
    if (cp == 0x000A or cp == 0x000D) return .B; // Line breaks

    return .ON; // Other neutral (default)
}

/// Utility function to reverse a range for RTL display
pub fn reverseRange(text: []u32, start: usize, end: usize) void {
    var left = start;
    var right = end;

    while (left < right) {
        const temp = text[left];
        text[left] = text[right - 1];
        text[right - 1] = temp;
        left += 1;
        right -= 1;
    }
}

/// High-level function to reorder text for display
pub fn reorderForDisplay(
    allocator: std.mem.Allocator,
    text: []const u32,
    base_dir: Direction,
) ![]u32 {
    var bidi = BiDi.init(allocator);

    // Process text to get runs
    const runs = try bidi.processText(text, base_dir);
    defer allocator.free(runs);

    // Create a copy for reordering
    const result = try allocator.dupe(u32, text);

    // Reverse RTL runs
    for (runs) |run| {
        if (run.isRTL()) {
            reverseRange(result, run.start, run.end());
        }
    }

    return result;
}

// Terminal-specific BiDi utilities

/// Calculate cursor position in BiDi text
pub fn calculateCursorPosition(
    allocator: std.mem.Allocator,
    text: []const u32,
    logical_pos: usize,
    base_dir: Direction,
) !usize {
    var bidi = BiDi.init(allocator);

    const runs = try bidi.processText(text, base_dir);
    defer allocator.free(runs);

    // Find which run contains the logical position
    for (runs) |run| {
        if (logical_pos >= run.start and logical_pos < run.end()) {
            if (run.isRTL()) {
                // In RTL run, visual position is reversed
                return run.end() - 1 - (logical_pos - run.start);
            } else {
                // In LTR run, visual position equals logical position
                return logical_pos;
            }
        }
    }

    return logical_pos; // Fallback
}

/// Convert visual position to logical position
pub fn visualToLogical(
    allocator: std.mem.Allocator,
    text: []const u32,
    visual_pos: usize,
    base_dir: Direction,
) !usize {
    var bidi = BiDi.init(allocator);

    const runs = try bidi.processText(text, base_dir);
    defer allocator.free(runs);

    var current_visual: usize = 0;

    for (runs) |run| {
        if (visual_pos >= current_visual and visual_pos < current_visual + run.length) {
            const offset_in_run = visual_pos - current_visual;
            if (run.isRTL()) {
                // In RTL run, logical position is reversed
                return run.start + (run.length - 1 - offset_in_run);
            } else {
                // In LTR run, logical position equals visual offset
                return run.start + offset_in_run;
            }
        }
        current_visual += run.length;
    }

    return visual_pos; // Fallback
}

test "BiDi basic LTR text" {
    const allocator = std.testing.allocator;

    const text = [_]u32{ 'H', 'e', 'l', 'l', 'o' };

    var bidi = BiDi.init(allocator);
    const base_dir = bidi.getBaseDirection(&text);

    try std.testing.expect(base_dir == .LTR);

    const runs = try bidi.processText(&text, base_dir);
    defer allocator.free(runs);

    try std.testing.expect(runs.len == 1);
    try std.testing.expect(runs[0].direction == .LTR);
    try std.testing.expect(runs[0].start == 0);
    try std.testing.expect(runs[0].length == 5);
}

test "BiDi basic RTL text" {
    const allocator = std.testing.allocator;

    // Hebrew text (simplified)
    const text = [_]u32{ 0x05D0, 0x05D1, 0x05D2 }; // Aleph, Bet, Gimel

    var bidi = BiDi.init(allocator);
    const base_dir = bidi.getBaseDirection(&text);

    try std.testing.expect(base_dir == .RTL);

    const runs = try bidi.processText(&text, base_dir);
    defer allocator.free(runs);

    try std.testing.expect(runs.len == 1);
    try std.testing.expect(runs[0].direction == .RTL);
}

test "BiDi mixed text" {
    const allocator = std.testing.allocator;

    // Mixed English and Hebrew
    const text = [_]u32{ 'H', 'e', 'l', 'l', 'o', ' ', 0x05D0, 0x05D1, 0x05D2 };

    var bidi = BiDi.init(allocator);
    const base_dir = bidi.getBaseDirection(&text);

    const runs = try bidi.processText(&text, base_dir);
    defer allocator.free(runs);

    // Should have multiple runs for mixed text
    try std.testing.expect(runs.len > 1);
}