---
name: wm-live-test
description: Run safe live integration tests for AeroSpace window layouts. Use when live-testing window layout, reproducing or diagnosing BSP or tiling bugs, verifying that a layout change works on screen, or when asked to see what the user sees.
---

# Window-manager live testing

Treat the user's window manager as a live production system. Collect a before/after snapshot for
every action and change one variable at a time.

## Preconditions and safety: hard rules

1. Verify AeroSpace is running and the installed binary contains the change under test:

   ```bash
   ps aux | grep -i '[A]eroSpace'
   command -v aerospace
   test -x "$(command -v aerospace)"
   aerospace --version
   stat -f 'installed: %Sm' -t '%Y-%m-%d %H:%M:%S %z' /Applications/AeroSpace.app/Contents/MacOS/AeroSpace
   git log -1 --format='commit:   %ci' -- <relevant-path>
   ```

   Require the client and server hashes printed by `aerospace --version` to match. If the CLI is
   not executable, the hashes differ, or the app is older than the relevant commit, stop and ask
   the user to reinstall/restart. Never restart, kill, replace, or install the window manager
   yourself.

2. Record the state needed for restoration before changing anything:

   ```bash
   initial_workspace="$(aerospace list-workspaces --focused)"
   initial_window_id="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
   aerospace list-windows --all --format '%{window-id} | %{workspace} | %{app-name} | %{window-title}'
   ```

3. Use an empty scratch workspace such as `Z` unless the bug is workspace-specific. Return to
   `$initial_workspace` and restore `$initial_window_id` when it still exists.

4. Never disturb pre-existing user windows. Before using TextEdit, check whether it is already
   running. If it is, stop and ask the user whether to use it or choose another disposable app.

5. Cleanup is mandatory even after a failed assertion: quit only the app instances spawned by the
   test, remove `/tmp/wmtest-*.txt` and captured scratch files, switch back to the initial workspace,
   and restore focus. Do not leave background `log stream` jobs running.

## Observation toolkit

Capture these before and after every individual spawn:

```bash
aerospace debug-tree --workspace Z
aerospace debug-tree --workspace Z --json
aerospace list-windows --all --format '%{window-id} | %{workspace} | %{app-name} | %{window-title}'
./.claude/skills/wm-live-test/dump-frames.py
log show --last 10m --info --style compact \
  --predicate 'subsystem CONTAINS "aerospace" AND category == "bsp"'
```

For a live trace, run this in a background shell and retain its PID for cleanup:

```bash
log stream --info --style compact \
  --predicate 'subsystem CONTAINS "aerospace" AND category == "bsp"'
```

In frame output, ignore owner `borders`. AeroSpace parks hidden windows at a monitor's bottom-right
corner, often with x near the screen width; exclude those parked frames from layout assertions.

## Spawning protocol

Create one window from one distinct, unmodified temporary file:

```bash
printf x > /tmp/wmtest-1.txt
open -a TextEdit /tmp/wmtest-1.txt
sleep 2
```

Repeat with a new number only after taking the full post-spawn snapshot. Unedited files avoid save
prompts during cleanup. With the default `bsp.insertion-point = 'tail'`, the BSP split anchors to the
deepest last-child window. A newly bound window becomes MRU, but focus changes must not alter the
insertion anchor. Never spawn two windows without an observation between them unless testing the
batch case.

## Canned scenarios

Use the scratch workspace's usable rectangle as W by H and allow for configured gaps and borders.
Assert tree topology first, then compare physical frames to the approximate formulas.

### Spiral of four

On an empty BSP workspace, spawn four windows sequentially and snapshot after each:

1. w1 occupies approximately W by H.
2. w1 and w2 are side-by-side, each approximately W/2 by H.
3. w1 remains left; w2 and w3 occupy the top-right and bottom-right, each W/2 by H/2.
4. w4 splits the bottom-right pane; w3 and w4 are each W/4 by H/2.

The tree must add one binary BSP container per split. Logs must show one insertion decision per
spawn and one orientation decision whenever `branch=bsp-split`.

### Two-window batch

Spawn two files without sleeping or observing between them. They must still finish side-by-side.
This covers the QUB-61 detection-timing regression.

### Close and reopen

Create two windows, close one, then immediately spawn another. The result must be side-by-side with
no retained single-child wrapper. This covers QUB-62 normalization.

### Refocus before spawn

Create a spiral of four and capture its tree. Starting from the most recently spawned window, run
`aerospace focus left` twice and capture the tree and focused window ID after each move. Spawn a
fifth window and capture the full post-spawn snapshot.

The focus changes must not alter the pre-existing tree. The fifth window must split the existing
spiral tail, preserving the order and topology of windows 1 through 4. The final tree must remain a
binary BSP spiral, with no flat root append. This covers the QUB-68 tail-insertion behavior when an
earlier window is focused.

### Refocus, close, and respawn

Start from a fresh spiral of four. Beginning at the most recently spawned window, run
`aerospace focus left` twice, record whichever window is now focused, and close that window. Capture
the tree immediately after the close, then spawn a new window and capture the full post-spawn
snapshot.

After the close, normalization must preserve the surviving windows' depth-first order and leave no
empty or single-child BSP container. The new window must split the new deepest last-child tail. The
result must remain a binary BSP spiral with no flat root append; closing an earlier window must not
cause the replacement window to insert at the old focus location.

### Floating anchor

Float and focus a test window with `aerospace layout floating`, then spawn another window. The new
window must split the most recent tiled window's slot rather than append flat. This covers QUB-63.

### Move node to workspace

Move a test window onto a populated BSP scratch workspace. Record its final tree location and the
`move-node-to-workspace` log event. A flat root append is the known pre-QUB-69 behavior.

### Layout-command interference

Run `aerospace layout tiles horizontal vertical`, then spawn a window. Confirm the failure signature
shows a non-BSP root and non-BSP insertion. Always restore with `aerospace layout bsp` before cleanup.

## Failure signatures

| Symptom | Likely cause | Confirm with |
| --- | --- | --- |
| New windows form columns at root | Root layout is not BSP, or a flat-append branch ran | `debug-tree` root layout and the log `branch` field |
| One split uses the wrong direction | Slot ratio or anchor was wrong | Orientation log anchor, slot, ratio, threshold, and decision |
| Cached and computed rectangles differ | Stale layout cache | `debug-tree` cached/computed rectangles |
| Window lands in an unexpected pane | A different window was MRU | `debug-tree` MRU marker before the spawn |

## Cleanup

Run cleanup even when the scenario fails:

```bash
osascript -e 'tell application "TextEdit" to quit'
rm -f /tmp/wmtest-*.txt
aerospace workspace "$initial_workspace"
test -z "$initial_window_id" || aerospace focus --window-id "$initial_window_id" || true
```

Only use the TextEdit quit command after confirming there were no pre-existing TextEdit windows.

## Reporting

Post findings to the relevant Linear issue in the AeroSpace project; never create a local task file.
Include the exact action sequence, before/after `debug-tree --json`, frame snapshots, the BSP log
excerpt, expected geometry, actual geometry, cleanup result, and whether the initial focus was
restored.
