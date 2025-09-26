# gcode Development Roadmap
## Staying Ahead for zfont Success

This roadmap ensures gcode provides all the Unicode semantics that zfont needs to successfully replace C dependencies in ghostshell.

---

## Current gcode Status: Strong Foundation ✅

**What we have working:**
- Unicode 15.1 property tables
- Emoji detection and sequences
- Grapheme cluster boundaries
- Character width calculation
- Case conversion
- UTF-8 processing

**Performance:** 3-level lookup tables, <5ns character lookups, ~350KB memory

---

## Immediate Priorities (Q1 2025)

### 1. BiDi Algorithm Implementation 🚨 CRITICAL
```zig
// What zfont needs from gcode
pub const BiDiClass = enum { L, R, AL, EN, ES, ET, AN, CS, NSM, BN, B, S, WS, ON };
pub fn getBiDiClass(cp: u21) BiDiClass;
pub fn resolveBiDi(text: []const u8, paragraph_level: u8) ![]BiDiRun;

// For ghostshell cursor positioning
pub fn logicalToVisual(text: []const u8, logical_pos: usize) usize;
pub fn visualToLogical(text: []const u8, visual_pos: usize) usize;
```

**Why critical:** Without BiDi, zfont can't handle Arabic/Hebrew text properly

### 2. Script Detection & Classification
```zig
// Tell zfont which shaping engine to use
pub const Script = enum {
    latin, arabic, devanagari, bengali, tamil, thai, myanmar,
    han, hiragana, katakana, hangul, hebrew, // ... etc
};
pub fn getScript(cp: u21) Script;
pub fn detectScriptRuns(text: []const u8) ![]ScriptRun;
```

**Why needed:** zfont needs to know "use Arabic shaping" vs "use Latin shaping"

### 3. Complete Word Boundary Rules (UAX #29)
```zig
// Current: basic ASCII word splitting ❌
// Needed: Full Unicode word boundary detection ✅
pub fn isWordBoundary(cp1: u21, cp2: u21, state: *WordBreakState) bool;
pub const WordIterator = struct { /* full UAX #29 */ };
```

**Why important:** For terminal word selection, search, copy/paste

---

## Medium Term (Q2 2025)

### 4. Line Breaking Algorithm (UAX #14)
```zig
// For terminal text wrapping
pub const LineBreakClass = enum { OP, CL, QU, GL, NS, EX, SY, IS, PR, PO, /* ... */ };
pub fn getLineBreakClass(cp: u21) LineBreakClass;
pub fn findLineBreaks(text: []const u8, width: usize) ![]BreakOpportunity;
```

### 5. Normalization Performance Boost
```zig
// Current: works but could be faster
// Target: SIMD-accelerated normalization for large text blocks
pub fn normalizeSimd(text: []const u8, form: NormalizationForm) ![]u8;
```

### 6. Advanced Emoji Semantics
```zig
// Enhanced emoji detection for zfont color rendering
pub fn isColorEmoji(cp: u21) bool;
pub fn emojiPresentationDefault(cp: u21) EmojiPresentation;
pub fn findEmojiSequences(text: []const u8) ![]EmojiSequence;
```

---

## Advanced Features (Q3-Q4 2025)

### 7. Indic Script Support
```zig
// For complex script shaping
pub const IndicFeatures = struct {
    has_vowel_signs: bool,
    has_consonant_clusters: bool,
    reordering_class: ReorderingClass,
};
pub fn analyzeIndicText(text: []const u8, script: Script) !IndicFeatures;
```

### 8. SIMD Acceleration
```zig
// Bulk operations for terminal performance
pub fn bulkGetWidth(codepoints: []const u21, widths: []u2) void; // AVX2/NEON
pub fn bulkValidateUtf8(bytes: []const u8) bool; // SIMD validation
pub fn bulkClassify(codepoints: []const u21, classes: []GraphemeBoundaryClass) void;
```

### 9. Memory-Mapped Unicode Data
```zig
// For faster startup and lower memory usage
pub fn loadFromMmap(unicode_data_file: []const u8) !void;
pub const CompressedTables = struct { /* even smaller tables */ };
```

---

## API Evolution for zfont Integration

### Current gcode API (working)
```zig
const gcode = @import("gcode");
const props = gcode.getProperties('A');
const width = gcode.getWidth('A');
```

### Enhanced API for zfont (Q1 2025)
```zig
// Script detection for shaping engine selection
const script_runs = try gcode.detectScriptRuns("Hello العالم");
for (script_runs) |run| {
    switch (run.script) {
        .latin => zfont.shapeWithLatin(run.text),
        .arabic => zfont.shapeWithArabic(run.text),
        // ...
    }
}

// BiDi support for cursor positioning
const bidi_runs = try gcode.resolveBiDi(text, .auto);
const visual_pos = gcode.logicalToVisual(text, cursor_logical_pos);
```

### Advanced API (Q2-Q3 2025)
```zig
// Complex script analysis
const text_analysis = try gcode.analyzeText(complex_text);
// text_analysis.script_runs, .bidi_runs, .line_breaks, .word_boundaries

// Performance APIs for terminals
var bulk_processor = gcode.BulkProcessor.init(allocator);
bulk_processor.processTextBlock(large_text_buffer); // SIMD accelerated
```

---

## Performance Targets

### Current Performance ✅
- Character property lookup: <5ns
- Grapheme iteration: ~10ns per grapheme
- Memory usage: ~350KB for all tables

### Target Performance (Q2 2025)
- BiDi resolution: <1μs per line
- Script detection: <100ns per character
- Bulk width calculation: >1GB/s throughput
- Memory usage: <500KB total

### Advanced Performance (Q4 2025)
- SIMD text processing: >5GB/s
- Memory-mapped tables: <100KB resident
- GPU compute integration: >50GB/s

---

## Keeping Up with Unicode Standards

### Unicode 16.0 Support (2025)
- [ ] New emoji sequences
- [ ] Script additions
- [ ] Property updates
- [ ] BiDi algorithm updates

### Continuous Updates
- Automated Unicode data download
- Property table regeneration
- Test suite updates
- Performance regression testing

---

## Success Metrics for zfont Support

### ✅ Foundation Complete
- [x] Emoji detection and sequences
- [x] Character width calculation
- [x] Grapheme cluster boundaries
- [x] Basic text segmentation

### 🎯 Q1 2025 Goals
- [ ] BiDi algorithm implementation
- [ ] Script detection system
- [ ] Complete word boundary rules
- [ ] Performance: <1μs BiDi per line

### 🎯 Q2 2025 Goals
- [ ] Line breaking algorithm
- [ ] Advanced emoji semantics
- [ ] SIMD acceleration framework
- [ ] Performance: >1GB/s bulk processing

### 🎯 Q3-Q4 2025 Goals
- [ ] Complex script analysis
- [ ] Memory optimization
- [ ] GPU compute preparation
- [ ] Unicode 16.0 support

---

## Development Strategy

### Parallel Development
- **gcode**: Focus on Unicode semantics and algorithms
- **zfont**: Focus on font loading and rendering
- **Integration**: Regular sync meetings and API design

### Testing Strategy
- Unicode conformance test suite
- Performance benchmarking vs ICU
- Real-world text corpus testing
- Integration testing with zfont

### Documentation
- Keep API documentation current
- Performance characteristics
- Unicode compliance notes
- Integration examples

---

## Bottom Line: gcode's Role

**gcode provides the intelligence, zfont provides the rendering**

- gcode: "This text is Arabic, needs RTL processing, has joining characters"
- zfont: "Got it, I'll apply Arabic shaping rules and render right-to-left"

- gcode: "This emoji sequence needs special handling"
- zfont: "I'll render it as a single color glyph"

- gcode: "Line break opportunity here based on Unicode rules"
- zfont: "I'll wrap the text at that position"

By keeping gcode ahead with robust Unicode semantics, we ensure zfont can focus on font technology without worrying about Unicode complexity.

---

*Priority: Keep gcode's Unicode semantics 6+ months ahead of zfont's rendering needs*