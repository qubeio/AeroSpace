# 001: BSP Layout — Core Implementation

**Status:** Backlog
**Created:** 2026-03-29

## Objective

Add `bsp` as a first-class layout type in AeroSpace. BSP (Binary Space Partitioning) splits containers recursively — each new window splits the most recently focused window's container in two. This is the structural foundation that all other BSP tasks depend on.

## Acceptance Criteria
- [ ] `Layout` enum in `Sources/Common/cmdArgs/impl/LayoutCmdArgs.swift` has a `.bsp` case
- [ ] `layoutRecursive` in `Sources/AppBundle/layout/layoutRecursive.swift` handles `.bsp` via a `layoutBSP` function
- [ ] `layoutBSP` renders correctly: single child gets full space; multiple children split proportionally by weight along the container's orientation
- [ ] `normalizeContainers.swift` does not break on BSP containers (no unwanted flattening of intentional BSP splits)
- [ ] Build passes: `./build-debug.sh`
- [ ] No regressions in existing tile/accordion layout tests

## Technical Notes

### Layout rendering (layoutBSP)
`layoutBSP` is nearly identical to `layoutTiles` — both split space proportionally by child weight along orientation. The BSP "magic" is in the tree structure (see task 003), not the renderer. Implement `layoutBSP` by adapting `layoutTiles`, keeping it simple.

File to add it to: `Sources/AppBundle/layout/layoutRecursive.swift` as a private extension on `TilingContainer`.

### Layout enum
`LayoutCmdArgs.swift` defines the `Layout` enum. Add `.bsp` case with raw value `"bsp"`. Also update `help` text.

### normalizeContainers guard
`normalizeContainers.swift` has a flatten normalization (`enableNormalizationFlattenContainers`) that collapses single-child containers. This will destroy BSP's tree structure. Add a guard: skip flattening if the container's layout is `.bsp`.

### Reference
Mrzrb's `layoutBSP` in `Sources/AppBundle/layout/layoutRecursive.swift` (origin/bsp branch at `/Users/andreas/source/repos/Mrzrb/AeroSpace`) is a clean reference — lift it directly, it's correct.

## Log
- 2026-03-29: Task created. Start here before any other BSP task.
