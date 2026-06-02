# 005: BSP Layout — Tests

**Status:** Backlog
**Created:** 2026-03-29

## Objective

Write a focused test suite for BSP layout covering insertion, rendering, and resize. Not exhaustive — cover the cases that matter.

## Acceptance Criteria
- [ ] `Sources/AppBundleTests/tree/BSPLayoutTest.swift` exists and passes
- [ ] Test: single window on BSP workspace — takes full space
- [ ] Test: second window added — tree splits correctly, both windows get ~50% of space
- [ ] Test: third window added — splits MRU window, existing split preserved
- [ ] Test: window closed — tree normalizes correctly (no orphan containers)
- [ ] Test: resize width — adjusts weight, sibling weight compensates
- [ ] Test: split direction logic — wide container → vertical split; tall container → horizontal split
- [ ] All tests pass via `./run-tests.sh`

## Technical Notes

Follow existing test patterns in `Sources/AppBundleTests/`. Look at `FocusCommandTest.swift` or `TreeTest.swift` for how the test harness sets up fake workspaces and windows.

Mrzrb's `BSPLayoutTest.swift` (1280 lines) is over-specified and tied to their implementation details. Don't copy it — use it as a reference for what scenarios to consider, then write clean targeted tests against your implementation.

Keep tests under 200 lines total. Quality over quantity.

**Depends on:** Tasks 001, 002, 003, 004

## Log
- 2026-03-29: Task created.
