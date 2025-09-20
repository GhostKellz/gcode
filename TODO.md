# TODO_GCODE.md - Development Roadmap

🎯 **Mission: Create the fastest, most efficient Unicode library for terminal emulators**

## Phase 1: Foundation & Architecture ⚡

### Core Library Structure
- [ ] **Setup repository structure**
  ```
  gcode/
  ├── src/
  │   ├── lib.zig          # Main API exports
  │   ├── properties.zig   # Character property definitions
  │   ├── lookup.zig       # 3-level lookup table implementation
  │   ├── grapheme.zig     # Grapheme boundary detection
  │   ├── width.zig        # Character width calculation
  │   └── utf8.zig         # UTF-8 utilities
  ├── codegen/
  │   ├── generator.zig    # Table generation from Unicode data
  │   ├── fetch_unicode.zig # Download Unicode database files
  │   └── compress.zig     # Table compression algorithms
  ├── tests/
  ├── bench/
  └── build.zig
  ```

- [ ] **Core data structures (extract from Ghostshell)**
  ```zig
  pub const Properties = packed struct {
      width: u2,                    // 0=zero, 1=narrow, 2=wide, 3=reserved
      boundary_class: BoundaryClass(u4),  // Grapheme boundary classification
      // Pack into 8 bits total for cache efficiency
  };

  pub const BoundaryClass = enum(u4) {
      other = 0,
      extend = 1,
      prepend = 2,
      spacing_mark = 3,
      regional_indicator = 4,
      extended_pictographic = 5,
      extended_pictographic_base = 6,
      zwj = 7,
      // 8 values fit in 4 bits
  };
  ```

- [ ] **3-Level lookup table system (from Ghostshell's lut.zig)**
  - Extract and modernize the compression algorithm
  - Make it v0.16 compatible
  - Optimize for terminal-specific properties

### Data Generation Pipeline
- [ ] **Unicode data fetcher**
  - Download from Unicode.org directly (no ziglyph dependency)
  - Parse only what we need: EastAsianWidth.txt, GraphemeBreakProperty.txt
  - Create minimal data structures

- [ ] **Table generator**
  - Port Ghostshell's generator logic
  - Add compression optimizations
  - Generate static lookup tables at compile time

## Phase 2: Core Functionality 🚀

### Character Properties
- [ ] **Width detection**
  ```zig
  pub fn getWidth(codepoint: u21) u2;
  pub fn stringWidth(utf8_string: []const u8) usize;
  ```

- [ ] **Property lookup**
  ```zig
  pub fn getProperties(codepoint: u21) Properties;
  pub fn isWideCharacter(codepoint: u21) bool;
  pub fn isZeroWidth(codepoint: u21) bool;
  ```

### Grapheme Boundary Detection
- [ ] **State machine (from Ghostshell's grapheme.zig)**
  ```zig
  pub const GraphemeBreakState = packed struct(u2) {
      extended_pictographic: bool = false,
      regional_indicator: bool = false,
  };

  pub fn isGraphemeBoundary(cp1: u21, cp2: u21, state: *GraphemeBreakState) bool;
  ```

- [ ] **Iterator API**
  ```zig
  pub fn graphemeIterator(utf8_string: []const u8) GraphemeIterator;
  ```

### UTF-8 Utilities
- [ ] **Basic encoding/decoding**
  ```zig
  pub const utf8 = struct {
      pub fn decode(bytes: []const u8) !u21;
      pub fn encode(codepoint: u21, buffer: []u8) !usize;
      pub fn validate(bytes: []const u8) bool;
  };
  ```

## Phase 3: Terminal Optimizations ⚡

### Performance Optimizations
- [ ] **SIMD-optimized string width calculation**
- [ ] **Batch property lookup for strings**
- [ ] **Cache-friendly memory layout**
- [ ] **Branch prediction optimizations**

### Terminal-Specific Features
- [ ] **Control character handling**
  ```zig
  pub fn isControlCharacter(codepoint: u21) bool;
  pub fn isDisplayableInTerminal(codepoint: u21) bool;
  ```

- [ ] **Cursor movement helpers**
  ```zig
  pub fn findPreviousGrapheme(text: []const u8, pos: usize) usize;
  pub fn findNextGrapheme(text: []const u8, pos: usize) usize;
  ```

- [ ] **Terminal width calculation**
  ```zig
  pub fn calculateDisplayColumns(text: []const u8, tab_width: u8) usize;
  ```

## Phase 4: Advanced Features 🔥

### Emoji Support
- [ ] **Emoji sequence detection**
  - Zero-width joiner (ZWJ) sequences
  - Emoji modifier sequences
  - Flag sequences (regional indicators)

- [ ] **Emoji width calculation**
  - Handle presentation selectors (U+FE0E, U+FE0F)
  - Modifier base + modifier combinations

### Extended Unicode Support
- [ ] **Normalization forms** (if needed for terminals)
  - NFD (Canonical Decomposition)
  - NFC (Canonical Composition)

- [ ] **Case conversion** (for search/input)
  ```zig
  pub fn toLower(codepoint: u21) u21;
  pub fn toUpper(codepoint: u21) u21;
  ```

## Phase 5: Integration & Testing 🧪

### Comprehensive Testing
- [ ] **Unit tests for all APIs**
- [ ] **Property accuracy tests against Unicode test suite**
- [ ] **Grapheme boundary test suite**
- [ ] **Fuzzing for edge cases**

### Performance Benchmarking
- [ ] **Micro-benchmarks vs zg, ziglyph**
- [ ] **Memory usage profiling**
- [ ] **Real-world terminal emulator integration tests**

### Ghostshell Integration
- [ ] **Replace Ghostshell's unicode module with gcode**
- [ ] **Verify no performance regressions**
- [ ] **Test with complex Unicode text rendering**

## Technical Specifications 📋

### Performance Targets
- **Lookup Speed**: < 5ns per character property lookup
- **Memory Usage**: < 500KB total (tables + code)
- **Binary Size**: < 100KB when statically linked
- **Zero Allocations**: All hot paths allocation-free

### Compatibility
- **Zig Version**: 0.16+ (designed for modern Zig)
- **Unicode Version**: 16.0.0 (latest as of 2025)
- **Platforms**: All platforms Zig supports
- **Dependencies**: Zero runtime dependencies

### API Design Principles
1. **Terminal-First**: Every API designed for terminal use cases
2. **Zero-Cost Abstractions**: No performance overhead
3. **Memory Safe**: Leverage Zig's safety guarantees
4. **Async-Friendly**: Compatible with async/await patterns
5. **Composable**: APIs work together naturally

## Success Metrics 🎯

### Quantitative Goals
- [ ] 10x smaller binary size than ziglyph
- [ ] 5x faster property lookups than zg
- [ ] 100% compatibility with Unicode test suite
- [ ] Zero memory leaks in fuzzing tests
- [ ] < 1ms cold start time

### Qualitative Goals
- [ ] Used by multiple terminal emulator projects
- [ ] Becomes the standard Unicode library for Zig terminals
- [ ] Inspires similar optimizations in other languages
- [ ] Clean, well-documented API that's easy to use

## Development Notes 💡

### Extraction Strategy from Ghostshell
1. Copy `src/unicode/` directory structure
2. Modernize for standalone use (remove Ghostshell-specific parts)
3. Make v0.16 compatible from the start
4. Add proper error handling and validation
5. Create comprehensive test suite

### Key Insights to Preserve
- Ghostshell's 3-level lookup is superior to tries
- Precomputed grapheme boundaries are faster than runtime calculation
- Terminal-specific optimizations matter more than general Unicode completeness
- Memory layout optimization is crucial for performance

### Innovation Opportunities
- SIMD acceleration for batch operations
- Compile-time table generation for specific character sets
- Adaptive compression based on usage patterns
- Integration with rendering pipelines

---

**🚀 Let's build the future of terminal Unicode processing!**