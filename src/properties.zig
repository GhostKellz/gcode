/// Unicode script property (UAX #24), full UCD 16.0.0 value set.
/// Canonical home for the script enum; `script.zig` re-exports this so the
/// public API stays stable. Names match the UCD `Scripts.txt` property values
/// (valid Zig identifiers). Unmapped/unassigned code points map to `.Unknown`.
pub const Script = enum(u8) {
    Adlam,
    Ahom,
    Anatolian_Hieroglyphs,
    Arabic,
    Armenian,
    Avestan,
    Balinese,
    Bamum,
    Bassa_Vah,
    Batak,
    Bengali,
    Bhaiksuki,
    Bopomofo,
    Brahmi,
    Braille,
    Buginese,
    Buhid,
    Canadian_Aboriginal,
    Carian,
    Caucasian_Albanian,
    Chakma,
    Cham,
    Cherokee,
    Chorasmian,
    Common,
    Coptic,
    Cuneiform,
    Cypriot,
    Cypro_Minoan,
    Cyrillic,
    Deseret,
    Devanagari,
    Dives_Akuru,
    Dogra,
    Duployan,
    Egyptian_Hieroglyphs,
    Elbasan,
    Elymaic,
    Ethiopic,
    Garay,
    Georgian,
    Glagolitic,
    Gothic,
    Grantha,
    Greek,
    Gujarati,
    Gunjala_Gondi,
    Gurmukhi,
    Gurung_Khema,
    Han,
    Hangul,
    Hanifi_Rohingya,
    Hanunoo,
    Hatran,
    Hebrew,
    Hiragana,
    Imperial_Aramaic,
    Inherited,
    Inscriptional_Pahlavi,
    Inscriptional_Parthian,
    Javanese,
    Kaithi,
    Kannada,
    Katakana,
    Kawi,
    Kayah_Li,
    Kharoshthi,
    Khitan_Small_Script,
    Khmer,
    Khojki,
    Khudawadi,
    Kirat_Rai,
    Lao,
    Latin,
    Lepcha,
    Limbu,
    Linear_A,
    Linear_B,
    Lisu,
    Lycian,
    Lydian,
    Mahajani,
    Makasar,
    Malayalam,
    Mandaic,
    Manichaean,
    Marchen,
    Masaram_Gondi,
    Medefaidrin,
    Meetei_Mayek,
    Mende_Kikakui,
    Meroitic_Cursive,
    Meroitic_Hieroglyphs,
    Miao,
    Modi,
    Mongolian,
    Mro,
    Multani,
    Myanmar,
    Nabataean,
    Nag_Mundari,
    Nandinagari,
    Newa,
    New_Tai_Lue,
    Nko,
    Nushu,
    Nyiakeng_Puachue_Hmong,
    Ogham,
    Ol_Chiki,
    Old_Hungarian,
    Old_Italic,
    Old_North_Arabian,
    Old_Permic,
    Old_Persian,
    Old_Sogdian,
    Old_South_Arabian,
    Old_Turkic,
    Old_Uyghur,
    Ol_Onal,
    Oriya,
    Osage,
    Osmanya,
    Pahawh_Hmong,
    Palmyrene,
    Pau_Cin_Hau,
    Phags_Pa,
    Phoenician,
    Psalter_Pahlavi,
    Rejang,
    Runic,
    Samaritan,
    Saurashtra,
    Sharada,
    Shavian,
    Siddham,
    SignWriting,
    Sinhala,
    Sogdian,
    Sora_Sompeng,
    Soyombo,
    Sundanese,
    Sunuwar,
    Syloti_Nagri,
    Syriac,
    Tagalog,
    Tagbanwa,
    Tai_Le,
    Tai_Tham,
    Tai_Viet,
    Takri,
    Tamil,
    Tangsa,
    Tangut,
    Telugu,
    Thaana,
    Thai,
    Tibetan,
    Tifinagh,
    Tirhuta,
    Todhri,
    Toto,
    Tulu_Tigalari,
    Ugaritic,
    Vai,
    Vithkuqi,
    Wancho,
    Warang_Citi,
    Yezidi,
    Yi,
    Zanabazar_Square,

    /// Unassigned or unmapped code points (UCD `Unknown`).
    Unknown,

    /// Returns true if this script requires complex text shaping.
    pub fn requiresComplexShaping(self: Script) bool {
        return switch (self) {
            // Arabic script family - joining, contextual forms
            .Arabic, .Syriac, .Thaana, .Nko => true,

            // Indic scripts - complex syllable formation
            .Devanagari,
            .Bengali,
            .Gurmukhi,
            .Gujarati,
            .Oriya,
            .Tamil,
            .Telugu,
            .Kannada,
            .Malayalam,
            .Sinhala,
            => true,

            // Southeast Asian scripts - line breaking, positioning
            .Thai, .Lao, .Myanmar, .Khmer => true,

            // Tibetan and Mongolian - stacking, positioning
            .Tibetan, .Mongolian => true,

            else => false,
        };
    }

    /// Returns true if this script is written right-to-left.
    pub fn isRTL(self: Script) bool {
        return switch (self) {
            .Hebrew, .Arabic, .Syriac, .Thaana, .Nko => true,
            else => false,
        };
    }

    /// Returns true if this script uses joining behavior (like Arabic).
    pub fn hasJoining(self: Script) bool {
        return switch (self) {
            .Arabic, .Syriac, .Mongolian => true,
            else => false,
        };
    }

    /// Returns true if this script is typically monospace-incompatible.
    pub fn isMonospaceChallenge(self: Script) bool {
        return switch (self) {
            .Devanagari,
            .Bengali,
            .Thai,
            .Myanmar,
            .Khmer,
            .Tibetan,
            => true,
            else => false,
        };
    }

    /// Returns the typical text direction for this script.
    pub fn getTextDirection(self: Script) enum { ltr, rtl, ttb } {
        return switch (self) {
            .Hebrew, .Arabic, .Syriac, .Thaana, .Nko => .rtl,
            .Mongolian => .ttb, // top-to-bottom (though can be horizontal)
            else => .ltr,
        };
    }

    /// Returns true if this script commonly uses combining marks.
    pub fn usesCombiningMarks(self: Script) bool {
        return switch (self) {
            .Latin, .Greek, .Cyrillic => true, // diacritics
            .Hebrew, .Arabic => true, // points, marks
            .Devanagari, .Bengali, .Thai, .Myanmar => true, // vowel marks
            else => false,
        };
    }
};

/// Unicode bidirectional character class (UAX #9), full set from
/// `DerivedBidiClass.txt`. Canonical home; `bidi.zig` re-exports this.
pub const BiDiClass = enum(u5) {
    // Strong
    L, // Left_To_Right
    R, // Right_To_Left
    AL, // Arabic_Letter
    // Weak
    EN, // European_Number
    ES, // European_Separator
    ET, // European_Terminator
    AN, // Arabic_Number
    CS, // Common_Separator
    NSM, // Nonspacing_Mark
    BN, // Boundary_Neutral
    // Neutral
    B, // Paragraph_Separator
    S, // Segment_Separator
    WS, // White_Space
    ON, // Other_Neutral
    // Explicit formatting
    LRE, // Left_To_Right_Embedding
    LRO, // Left_To_Right_Override
    RLE, // Right_To_Left_Embedding
    RLO, // Right_To_Left_Override
    PDF, // Pop_Directional_Format
    LRI, // Left_To_Right_Isolate
    RLI, // Right_To_Left_Isolate
    FSI, // First_Strong_Isolate
    PDI, // Pop_Directional_Isolate

    /// Returns true if this is a strong directional character.
    pub fn isStrong(self: BiDiClass) bool {
        return switch (self) {
            .L, .R, .AL => true,
            else => false,
        };
    }

    /// Returns true if this is a neutral character.
    pub fn isNeutral(self: BiDiClass) bool {
        return switch (self) {
            .B, .S, .WS, .ON => true,
            else => false,
        };
    }

    /// Returns true if this is an RTL character.
    pub fn isRTL(self: BiDiClass) bool {
        return switch (self) {
            .R, .AL => true,
            else => false,
        };
    }

    /// Returns true if this is an isolate initiator.
    pub fn isIsolateInitiator(self: BiDiClass) bool {
        return switch (self) {
            .LRI, .RLI, .FSI => true,
            else => false,
        };
    }
};

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

    /// Unicode script (UAX #24). Defaults to `.Unknown`.
    script: Script = .Unknown,

    /// Bidirectional character class (UAX #9). Defaults to `.L`, the
    /// `DerivedBidiClass.txt` global `@missing` default (Left_To_Right).
    bidi_class: BiDiClass = .L,

    pub fn eql(a: Properties, b: Properties) bool {
        return a.width == b.width and
            a.ambiguous_width == b.ambiguous_width and
            a.grapheme_boundary_class == b.grapheme_boundary_class and
            a.word_break_class == b.word_break_class and
            a.combining_class == b.combining_class and
            a.uppercase == b.uppercase and
            a.lowercase == b.lowercase and
            a.titlecase == b.titlecase and
            a.script == b.script and
            a.bidi_class == b.bidi_class;
    }
};

pub const AmbiguousWidthPolicy = enum {
    narrow,
    wide,
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
            .grapheme_boundary_class = .invalid,
        };

        // Basic width detection (will be enhanced by Unicode data)
        if (cp <= 0x7F) {
            // ASCII fast path - control characters are zero-width
            if (cp < 0x20 or cp == 0x7F) {
                props.width = 0;
            }
            // All other ASCII characters use default grapheme class (invalid)
            // Real values come from generated Unicode tables
        }

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
    // Format controls used inside terminal grapheme clusters should not advance
    // the cursor even when table data classifies their East Asian width as neutral.
    if (cp == 0x200D or
        (cp >= 0xFE00 and cp <= 0xFE0F) or
        (cp >= 0xE0100 and cp <= 0xE01EF)) return 0;

    return getProperties(cp).width;
}

/// Get display width with an explicit East Asian Ambiguous width policy.
/// Most terminals use narrow ambiguous width by default; CJK-focused terminals
/// may opt into wide ambiguous width for legacy compatibility.
pub fn getWidthWithPolicy(cp: u21, policy: AmbiguousWidthPolicy) u2 {
    const width = getWidth(cp);
    if (width == 1 and policy == .wide and getProperties(cp).ambiguous_width) return 2;
    return width;
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
