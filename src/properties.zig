const std = @import("std");
const lut = @import("lut.zig");

/// Property set per codepoint that gcode cares about.
/// Optimized for terminal emulators with minimal memory footprint.
/// Compatible with Ghostshell's unicode module API.
pub const Properties = packed struct {
    /// Codepoint width clamped to [0, 2].
    width: u2 = 1,

    /// True when the character is East Asian Ambiguous width.
    ambiguous_width: bool = false,

    /// Grapheme cluster break class.
    grapheme_boundary_class: GraphemeBoundaryClass = .invalid,

    /// Word break class.
    word_break_class: WordBreakClass = .other,

    /// Canonical combining class.
    combining_class: u8 = 0,

    /// Uppercase mapping (0 when no mapping exists).
    uppercase: u21 = 0,

    /// Lowercase mapping (0 when no mapping exists).
    lowercase: u21 = 0,

    /// Titlecase mapping (0 when no mapping exists).
    titlecase: u21 = 0,

    pub fn eql(a: Properties, b: Properties) bool {
        return a.width == b.width and
            a.ambiguous_width == b.ambiguous_width and
            a.grapheme_boundary_class == b.grapheme_boundary_class and
            a.word_break_class == b.word_break_class and
            a.combining_class == b.combining_class and
            a.uppercase == b.uppercase and
            a.lowercase == b.lowercase and
            a.titlecase == b.titlecase;
    }

    pub fn format(
        self: Properties,
        comptime layout: []const u8,
        opts: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = layout;
        _ = opts;
        try writer.print(
            ".{{ .width = {d}, .ambiguous_width = {}, .grapheme_boundary_class = .{s}, .word_break_class = .{s}, .combining_class = {d}, .uppercase = {d}, .lowercase = {d}, .titlecase = {d} }}",
            .{
                self.width,
                self.ambiguous_width,
                @tagName(self.grapheme_boundary_class),
                @tagName(self.word_break_class),
                self.combining_class,
                self.uppercase,
                self.lowercase,
                self.titlecase,
            },
        );
    }
};

/// Possible grapheme boundary classes. This isn't an exhaustive list:
/// we omit control, CR, LF, etc. because in terminal usage that are
/// impossible because they're handled by the terminal.
/// Compatible with Ghostshell's unicode module.
pub const GraphemeBoundaryClass = enum(u4) {
    invalid,
    L,
    V,
    T,
    LV,
    LVT,
    prepend,
    extend,
    zwj,
    spacing_mark,
    regional_indicator,
    extended_pictographic,
    extended_pictographic_base, // \p{Extended_Pictographic} & \p{Emoji_Modifier_Base}
    emoji_modifier, // \p{Emoji_Modifier}

    /// Returns true if this is an extended pictographic type. This
    /// should be used instead of comparing the enum value directly
    /// because we classify multiple.
    pub fn isExtendedPictographic(self: GraphemeBoundaryClass) bool {
        return switch (self) {
            .extended_pictographic,
            .extended_pictographic_base,
            => true,

            else => false,
        };
    }
};

/// Word break classes for Unicode word boundary detection.
/// Based on Unicode Standard Annex #29.
pub const WordBreakClass = enum(u5) {
    other,
    cr,
    lf,
    newline,
    extend,
    regional_indicator,
    format,
    katakana,
    hebrew_letter,
    aletter,
    midletter,
    midnum,
    midnumlet,
    numeric,
    extendnumlet,
    zwj,
    wsegspace,
    single_quote,
    double_quote,
    ebase,
    ebase_gaz,
    emodifier,
    glue_after_zwj,
};

/// Context for generating Unicode property tables.
/// This will be used by the codegen system to build lookup tables.
pub const GeneratorContext = struct {
    /// Get properties for a codepoint (slow path for table generation)
    pub fn get(ctx: @This(), cp: u21) Properties {
        _ = ctx;

        // Default properties - will be overridden by data generator
        var props = Properties{
            .width = 1, // Default to narrow
            .grapheme_boundary_class = .other,
        };

        // Basic width detection (will be enhanced by Unicode data)
        if (cp <= 0x7F) {
            // ASCII fast path
            if (cp < 0x20 or cp == 0x7F) {
                props.width = 0; // Control characters
            } else if (cp >= 'a' and cp <= 'z') {
                props.grapheme_boundary_class = .letter;
            } else if (cp >= 'A' and cp <= 'Z') {
                props.grapheme_boundary_class = .letter;
            } else if (cp >= '0' and cp <= '9') {
                props.grapheme_boundary_class = .number;
            } else if ((cp >= 0x20 and cp <= 0x2F) or (cp >= 0x3A and cp <= 0x40) or
                (cp >= 0x5B and cp <= 0x60) or (cp >= 0x7B and cp <= 0x7E))
            {
                props.grapheme_boundary_class = .punctuation;
            } else if (cp == 0x20 or cp == 0x09 or cp == 0x0A or cp == 0x0D) {
                props.grapheme_boundary_class = .separator;
            }
        }

        // TODO: This will be populated by the Unicode data generator
        // For now, return defaults

        return props;
    }

    /// Check if two property sets are equal
    pub fn eql(ctx: @This(), a: Properties, b: Properties) bool {
        _ = ctx;
        return a.eql(b);
    }
};

/// The compiled lookup tables.
/// These will be generated at build time from Unicode data.
pub const tables = @import("unicode_tables.zig").tables;

/// Get properties for a Unicode codepoint.
/// This is the main API - O(1) lookup using 3-level tables.
pub fn getProperties(cp: u21) Properties {
    return tables.get(cp);
}

/// Get the display width of a codepoint.
/// Returns: 0=zero-width, 1=narrow, 2=wide
pub fn getWidth(cp: u21) u2 {
    return getProperties(cp).width;
}

/// Check if a codepoint is zero-width
pub fn isZeroWidth(cp: u21) bool {
    return getWidth(cp) == 0;
}

/// Check if a codepoint is wide (double-width)
pub fn isWide(cp: u21) bool {
    return getWidth(cp) == 2;
}

/// Check if a codepoint is narrow (single-width)
pub fn isNarrow(cp: u21) bool {
    return getWidth(cp) == 1;
}
