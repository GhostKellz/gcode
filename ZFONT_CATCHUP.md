# ZFONT Catchup Checklist

This document outlines the features that `gcode` (our Unicode library) must support to enable `zfont` to fully replace C dependencies in Ghostshell, particularly FreeType, FontConfig, Pango, and HarfBuzz.

## Current Status Overview

✅ **Completed in gcode**
⏳ **Planned for zfont**
🔄 **Needs gcode enhancement**
❌ **Missing entirely**

---

## 1. Unicode Text Processing (gcode responsibility)

### ✅ Core Unicode Support
- [x] Unicode 15.1 data tables
- [x] 3-level compressed lookup tables
- [x] Character properties (width, category, etc.)
- [x] Case conversion (upper/lower/titlecase)
- [x] East Asian Width detection
- [x] Zero-width character handling

### ✅ Grapheme Cluster Detection
- [x] Grapheme boundary detection (UAX #29)
- [x] Emoji modifier sequences (Fitzpatrick skin tones)
- [x] ZWJ (Zero Width Joiner) sequences
- [x] Regional indicator pairs (flag emojis)
- [x] Complex emoji sequences
- [x] Combining mark handling

### ✅ Text Segmentation
- [x] Grapheme cluster iteration
- [x] Reverse grapheme iteration
- [x] Cursor movement helpers
- [x] UTF-8 validation and processing

### 🔄 Word Boundary Detection (needs enhancement)
- [x] Basic word iteration
- [ ] **TODO**: Full UAX #29 word boundary rules
- [ ] **TODO**: Language-specific word breaking
- [ ] **TODO**: Line breaking opportunities

### ❌ Bidirectional Text (BiDi) - Critical for Terminal
- [ ] **TODO**: BiDi algorithm implementation (UAX #9)
- [ ] **TODO**: RTL/LTR text flow detection
- [ ] **TODO**: Mixed-direction line handling
- [ ] **TODO**: Terminal cursor positioning in BiDi text
- [ ] **TODO**: Arabic script contextual forms
- [ ] **TODO**: Hebrew text processing

---

## 2. Font Loading & Metrics (zfont responsibility)

### ⏳ Font File Parsing
- [ ] TrueType (.ttf) parser
- [ ] OpenType (.otf) parser
- [ ] WOFF/WOFF2 web font support
- [ ] Font collection (.ttc) support
- [ ] Variable font support

### ⏳ Font Metrics Extraction
- [ ] Character width calculation
- [ ] Baseline metrics
- [ ] Line height calculation
- [ ] Kerning pair extraction
- [ ] Bearing calculations

### ⏳ Font Discovery & Matching
- [ ] System font enumeration
- [ ] Font family matching
- [ ] Weight/style matching
- [ ] Fallback font chains
- [ ] Font cache management

---

## 3. Glyph Rendering (zfont responsibility)

### ⏳ Rasterization
- [ ] Glyph outline conversion
- [ ] Hinting support
- [ ] Subpixel rendering
- [ ] Anti-aliasing
- [ ] Bitmap glyph support

### ⏳ Emoji & Color Support
- [ ] Color emoji (CBDT/CBLC tables)
- [ ] SVG emoji support
- [ ] Emoji presentation vs text presentation
- [ ] Skin tone modifier rendering
- [ ] Multi-codepoint emoji sequences

---

## 4. Text Shaping (critical for replacing HarfBuzz)

### 🔄 Basic Shaping Engine (gcode/zfont collaboration)
- [ ] **gcode**: Script detection and classification
- [ ] **zfont**: Glyph substitution engine
- [ ] **zfont**: Glyph positioning engine
- [ ] **gcode**: Character-to-glyph mapping

### ❌ Complex Script Support
- [ ] **TODO**: Arabic script joining rules
- [ ] **TODO**: Indic script processing (Devanagari, Tamil, etc.)
- [ ] **TODO**: Thai/Lao script handling
- [ ] **TODO**: Myanmar script support
- [ ] **TODO**: Hebrew script processing

### ❌ OpenType Features
- [ ] **TODO**: GSUB (Glyph Substitution) table processing
- [ ] **TODO**: GPOS (Glyph Positioning) table processing
- [ ] **TODO**: Ligature formation
- [ ] **TODO**: Contextual alternates
- [ ] **TODO**: Mark positioning

### 🔄 Terminal-Specific Features
- [ ] **gcode**: Programming ligatures detection
- [ ] **zfont**: Monospace enforcement
- [ ] **zfont**: Character width normalization
- [ ] **gcode**: Double-width character handling (CJK)

---

## 5. Terminal Emulator Integration

### ✅ Character Width for Terminal Cells
- [x] Narrow/Normal/Wide classification
- [x] Zero-width character detection
- [x] Ambiguous width handling
- [x] String width calculation

### 🔄 Cursor Positioning
- [x] Basic grapheme-aware cursor movement
- [ ] **TODO**: BiDi cursor positioning
- [ ] **TODO**: Complex script cursor handling
- [ ] **TODO**: Visual vs logical cursor movement

### ❌ Terminal-Specific Text Features
- [ ] **TODO**: Line wrapping with proper breaks
- [ ] **TODO**: Tab expansion handling
- [ ] **TODO**: Control character visualization
- [ ] **TODO**: ANSI escape sequence parsing

---

## 6. Performance Requirements for Terminal Use

### ✅ Memory Efficiency
- [x] Compressed lookup tables (~350KB total)
- [x] Minimal memory allocations
- [x] Cache-friendly data structures

### 🔄 Speed Optimizations
- [x] O(1) property lookups
- [x] ASCII fast path
- [ ] **TODO**: SIMD acceleration for bulk operations
- [ ] **TODO**: Glyph cache for repeated characters
- [ ] **TODO**: Incremental shaping for live editing

### ❌ Platform Optimizations
- [ ] **TODO**: x86_64 SIMD (AVX-512, BMI2)
- [ ] **TODO**: ARM64 NEON optimizations
- [ ] **TODO**: WebAssembly compatibility
- [ ] **TODO**: GPU compute shaders (future)

---

## 7. API Design for Ghostshell Integration

### 🔄 Text Processing Pipeline
```zig
// Current gcode API (working)
const props = gcode.getProperties('A');
const width = gcode.getWidth('A');
const is_boundary = gcode.graphemeBreak(cp1, cp2, &state);

// Needed zfont API (planned)
const shaped_text = zfont.shape(text, font_metrics);
const glyph_positions = zfont.layout(shaped_glyphs, constraints);
const rasterized = zfont.render(positioned_glyphs);
```

### ❌ Font Management API
```zig
// Needed for replacing FontConfig
const font = zfont.loadFont(font_path);
const best_match = zfont.findFont(.{
    .family = "Nerd Font",
    .weight = .normal,
    .style = .normal,
});
const fallback_chain = zfont.buildFallbackChain(primary_font);
```

### ❌ Terminal Integration API
```zig
// Needed for Ghostshell integration
const terminal_metrics = zfont.calculateTerminalMetrics(font, cell_size);
const cursor_pos = gcode.findCursorPosition(text, byte_offset);
const visual_width = gcode.calculateVisualWidth(text, terminal_metrics);
```

---

## 8. Testing & Validation Requirements

### 🔄 Unicode Compliance Testing
- [x] Basic Unicode property tests
- [ ] **TODO**: Unicode conformance test suite
- [ ] **TODO**: BiDi algorithm test suite
- [ ] **TODO**: Text segmentation test suite

### ❌ Font Compatibility Testing
- [ ] **TODO**: Common font format validation
- [ ] **TODO**: Nerd Font icon rendering tests
- [ ] **TODO**: Emoji sequence rendering tests
- [ ] **TODO**: Performance benchmarks vs C libraries

### ❌ Terminal Integration Testing
- [ ] **TODO**: Terminal emulator compatibility
- [ ] **TODO**: PowerLevel10k integration tests
- [ ] **TODO**: Complex script rendering validation
- [ ] **TODO**: Memory usage profiling

---

## 9. Migration Path from C Dependencies

### Phase 1: Core Unicode (gcode) ✅ COMPLETE
- [x] Replace basic Unicode operations
- [x] Emoji and grapheme cluster support
- [x] Character width calculation

### Phase 2: Basic Font Support (zfont) ⏳ IN PROGRESS
- [ ] TrueType/OpenType parsing
- [ ] Basic glyph rendering
- [ ] Font discovery and loading
- [ ] **Target**: Replace FreeType for basic text

### Phase 3: Text Shaping (gcode + zfont) ❌ PLANNED
- [ ] BiDi algorithm in gcode
- [ ] Complex script detection in gcode
- [ ] OpenType feature processing in zfont
- [ ] **Target**: Replace HarfBuzz for text shaping

### Phase 4: Advanced Features ❌ FUTURE
- [ ] Color emoji rendering
- [ ] Variable font support
- [ ] Advanced typography features
- [ ] **Target**: Feature parity with C libraries

---

## 10. Critical Blockers for Ghostshell Independence

### High Priority (Must Have)
1. **BiDi Algorithm**: Essential for international text
2. **Font Loading**: Basic TrueType/OpenType support
3. **Text Shaping**: At least Latin + Arabic + CJK
4. **Glyph Rendering**: Replacement for FreeType rasterization

### Medium Priority (Should Have)
1. **Complex Script Support**: Indic, Thai, Myanmar scripts
2. **OpenType Features**: Ligatures, contextual alternates
3. **Color Emoji**: Modern emoji rendering
4. **Performance Optimization**: SIMD acceleration

### Low Priority (Nice to Have)
1. **Variable Fonts**: Modern font technology
2. **Advanced Typography**: High-quality typesetting
3. **GPU Acceleration**: Compute shader text processing
4. **Platform Optimizations**: Architecture-specific code

---

## Success Metrics

### Performance Targets
- **Shaping Speed**: <50ns per character for Latin text
- **Memory Usage**: <1MB for shaping cache
- **Binary Size**: <200KB for full shaping support
- **Cache Hit Rate**: >95% for common terminal text

### Compatibility Goals
- **Font Support**: 100% compatibility with common TrueType/OpenType fonts
- **Unicode Coverage**: Support for all scripts used in terminals
- **Terminal Integration**: Seamless replacement in Ghostshell
- **PowerLevel10k**: Full compatibility with existing themes

---

## Implementation Timeline

### Q4 2024 (Current)
- [x] Complete gcode Unicode foundation
- [x] Emoji and grapheme cluster support
- [x] Character width and properties

### Q1 2025
- [ ] Begin zfont TrueType parser
- [ ] Basic font loading and metrics
- [ ] Simple glyph rendering

### Q2 2025
- [ ] BiDi algorithm in gcode
- [ ] Basic text shaping engine
- [ ] Arabic script support

### Q3 2025
- [ ] Complex script support (Indic, CJK)
- [ ] OpenType feature processing
- [ ] Performance optimizations

### Q4 2025
- [ ] Color emoji support
- [ ] Advanced typography features
- [ ] Complete C library replacement

---

*This document should be updated as features are implemented and requirements evolve.*