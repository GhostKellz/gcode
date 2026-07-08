# Architecture

gcode is centered on generated Unicode data tables plus small terminal-oriented
runtime helpers.

## Module Shape

```mermaid
flowchart LR
    root["src/lib.zig"] --> props["properties.zig"]
    root --> grapheme["grapheme.zig"]
    root --> word["word.zig"]
    root --> normalize["normalize.zig"]
    root --> bidi["bidi.zig"]
    root --> script["script / complex_script"]
    root --> shaping["shaping / advanced_shaping"]

    props --> tables["unicode_tables.zig"]
    grapheme --> tables
    word --> tables
    normalize --> tables
```

## Lookup Flow

```mermaid
flowchart TD
    cp["Unicode codepoint"] --> stage1["stage 1 block index"]
    stage1 --> stage2["stage 2 sub-block"]
    stage2 --> props["property row"]
    props --> width["display width"]
    props --> grapheme["grapheme class"]
    props --> case["case mapping"]
```

## Text Flow

```mermaid
flowchart TD
    bytes["UTF-8 bytes"] --> validate["validate/decode"]
    validate --> iter["codepoint/grapheme iterator"]
    iter --> props["property lookup"]
    props --> terminal["terminal width/cursor helpers"]
    props --> exp["BiDi/shaping experiments"]

    exp --> fixtures["needs conformance and downstream fixtures"]
```

## Boundaries

- gcode owns Unicode properties, segmentation helpers, terminal width, case, and normalization experiments.
- zfont should own font/glyph/layout/rendering behavior.
- Phantom/Ghostshell should own terminal rendering policy and app-level fallbacks.
- BiDi and shaping exports remain experimental until conformance and integration coverage are stronger.
