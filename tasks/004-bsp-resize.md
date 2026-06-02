# 004: BSP Layout — Resize Support

**Status:** Backlog
**Created:** 2026-03-29

## Objective

Make `aerospace resize` work correctly in BSP workspaces. This is the known hard part — Mrzrb's implementation explicitly ships with resize bugs. Solve it properly.

## Acceptance Criteria
- [ ] `resize width` adjusts the window's weight in its immediate parent container (horizontal orientation)
- [ ] `resize height` adjusts the window's weight in its immediate parent container (vertical orientation)
- [ ] `resize smart` / `resize smart-opposite` work correctly in nested BSP trees
- [ ] Resizing does not corrupt sibling weights (total weight remains consistent)
- [ ] Mouse resize (`resizeWithMouse.swift`) works in BSP containers
- [ ] Edge case: resizing a window that is the only child of its container is a no-op (not a crash)
- [ ] Build passes, existing resize tests pass

## Technical Notes

### Why Mrzrb's resize is broken
In a BSP tree, windows live inside nested containers. `ResizeCommand` looks for a parent container with the matching orientation, then adjusts the node's `adaptiveWeight`. The bug: when containers are nested (BSP creates many nested containers), the weight adjustment propagates to the wrong level, or sibling weights don't balance correctly.

### Fix approach
In `ResizeCommand.swift`, BSP containers should already work with the existing weight-adjustment logic IF the tree structure is correct. The fix is likely:
1. Ensure `candidates` search in `ResizeCommand` correctly traverses BSP container nesting
2. After weight adjustment, renormalize sibling weights in the same container so they sum correctly
3. For mouse resize (`resizeWithMouse.swift`), ensure `layout == .bsp` is treated like `.tiles` (which Mrzrb did — verify it's already there from task 001)

### Check first
Before writing new code, test if resize works at all after tasks 001-003 are done. It may work for simple (non-nested) cases. This task is specifically about fixing it for deeply nested BSP trees.

**Depends on:** Tasks 001, 002, 003

## Log
- 2026-03-29: Task created. Do not skip this — resize is table stakes for usability.
