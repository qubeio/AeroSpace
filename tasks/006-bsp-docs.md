# 006: BSP Layout — Docs & Config Example

**Status:** Backlog
**Created:** 2026-03-29

## Objective

Document the BSP layout feature so users know it exists, how to enable it, and how to configure it.

## Acceptance Criteria
- [ ] `docs/aerospace-layout.adoc` documents the `bsp` layout type alongside `tiles` and `accordion`
- [ ] `docs/config-examples/default-config.toml` includes a commented `[bsp]` section with defaults
- [ ] `docs/guide.adoc` mentions BSP in the layouts section (brief, links to layout doc)
- [ ] Config example shows: how to set a workspace to BSP layout, the `[bsp]` config block with all options
- [ ] Build passes (docs don't block build but check for broken asciidoc references)

## Technical Notes

### What to document
- `layout bsp` command enables BSP on current workspace
- `[bsp]` config section: `split-ratio`, `auto-split-threshold`, `preferred-split-direction`
- Behaviour description: new windows split the focused window; resize works as expected
- Note known limitation if any resize edge cases remain

### Config example snippet
```toml
[bsp]
split-ratio = 0.5
auto-split-threshold = 1.2
# preferred-split-direction = 'horizontal'  # or 'vertical'. Unset = auto
```

**Depends on:** Tasks 001–005 (write docs last, when behaviour is finalised)

## Log
- 2026-03-29: Task created.
