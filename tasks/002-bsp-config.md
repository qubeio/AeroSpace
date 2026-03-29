# 002: BSP Layout — Config & TOML Parsing

**Status:** Backlog
**Created:** 2026-03-29

## Objective

Add a `[bsp]` config section to AeroSpace's TOML config, giving users control over BSP split behaviour. Must follow existing config patterns exactly.

## Acceptance Criteria
- [ ] `BSPConfig` struct added to `Sources/AppBundle/config/Config.swift`
- [ ] `Config` has a `var bsp: BSPConfig` field
- [ ] `parseConfig.swift` registers a `"bsp"` parser using `bspConfigParser`
- [ ] `split-ratio` (Double, default 0.5) parses correctly
- [ ] `auto-split-threshold` (Double, default 1.2) parses correctly — aspect ratio above this = vertical split
- [ ] `preferred-split-direction` (optional `"horizontal"` | `"vertical"`, default nil) parses correctly
- [ ] Invalid values produce config parse errors (not crashes)
- [ ] Build passes

## Technical Notes

### BSPConfig struct
```swift
struct BSPConfig: ConvenienceCopyable {
    var splitRatio: Double = 0.5
    var autoSplitThreshold: Double = 1.2
    var preferredSplitDirection: Orientation? = nil
}
```

Place in `Config.swift` alongside other config structs.

### parseConfig.swift integration
Follow the exact pattern used for other nested config tables (e.g. `gaps`). Register via the top-level `configParser` dict:
```swift
"bsp": Parser(\.bsp, parseBSPConfig),
```

Add `bspConfigParser` and `parseBSPConfig` private functions. Reuse `parseDouble` (already exists), add `parseOptionalOrientation` (check if it already exists before adding).

### Reference
`Config.swift` and `parseConfig.swift` on Mrzrb's `origin/bsp` branch at `/Users/andreas/source/repos/Mrzrb/AeroSpace` — clean reference, lift directly.

**Depends on:** Task 001 (needs `.bsp` layout case to exist)

## Log
- 2026-03-29: Task created.
