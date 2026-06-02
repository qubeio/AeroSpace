# 003: BSP Layout — Window Insertion Algorithm

**Status:** Backlog
**Created:** 2026-03-29

## Objective

When a new window is added to a BSP workspace, it should split the most recently focused (MRU) window's container rather than appending to a flat list. This is the core behavioural difference between BSP and tiles.

## Acceptance Criteria
- [ ] New window on a BSP workspace splits the MRU window's position in the tree
- [ ] Split direction chosen intelligently: use `preferredSplitDirection` if set; otherwise use aspect ratio vs `autoSplitThreshold`; fall back to alternating orientation
- [ ] Split creates a new `TilingContainer` with the correct orientation, containing the original window and the new window at equal weight (`splitRatio`)
- [ ] Existing windows on non-BSP workspaces are unaffected
- [ ] Works correctly when the workspace has 1, 2, or many windows
- [ ] Works correctly after window close (tree cleans up via normalizeContainers)
- [ ] Build passes

## Technical Notes

### Where to hook in
Window binding happens in `MacWindow.swift` — find where new windows are bound to a workspace and add BSP-aware insertion logic. Check `onWindowDetected` flow.

### Keep it simple — ~50 lines max
Mrzrb's `insertWindowBSP` / `safeBSPSplit` is massively over-engineered (error types, retry logic, fallbacks). The algorithm is simple:

1. Find MRU window in workspace
2. Get its parent `TilingContainer`
3. Determine split orientation (aspect ratio logic from `BSPConfig`)
4. Create a new `TilingContainer` with that orientation at the MRU window's position
5. Bind MRU window and new window into it at `splitRatio` weights

Write this cleanly, ~40-60 lines, no custom error types needed. Use existing `BindingData`, `bind(to:adaptiveWeight:index:)`, `unbindFromParent()` patterns from the codebase.

### Split direction logic
```swift
func chooseSplitOrientation(for rect: Rect, config: BSPConfig) -> Orientation {
    if let preferred = config.preferredSplitDirection { return preferred }
    let ratio = rect.width / rect.height
    if ratio > config.autoSplitThreshold { return .v }
    if ratio < 1.0 / config.autoSplitThreshold { return .h }
    return currentOrientation.opposite
}
```

**Depends on:** Tasks 001, 002

## Log
- 2026-03-29: Task created. This is the heart of BSP — keep it simple.
