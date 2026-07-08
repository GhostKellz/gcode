# Emoji Semantics

gcode should own emoji classification and cluster semantics. Rendering, glyph
fallback, color emoji tables, and font selection belong in zfont or a renderer.

## gcode Responsibilities

- identify emoji-related codepoint properties from generated Unicode data
- preserve grapheme clusters for ZWJ sequences, skin tones, and flags
- provide display-width policy used by terminal consumers
- expose stable iteration/cursor helpers once conformance tests are present

## Out Of Scope For gcode

- color glyph rendering
- font fallback
- image/vector emoji assets
- OpenType color table handling
- terminal drawing

## Test Cases

- simple emoji: `😀`
- skin tone: `👍🏽`
- family ZWJ sequence: `👨‍👩‍👧‍👦`
- rainbow flag: `🏳️‍🌈`
- regional flags: `🇺🇸`
- keycap sequences: `1️⃣`
