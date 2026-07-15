#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyobjc-framework-Quartz", "pyobjc-framework-Cocoa"]
# ///
"""Print screens and all layer-0 window frames: OWNER x y w h."""

import Quartz
from AppKit import NSScreen


for screen in NSScreen.screens():
    frame = screen.frame()
    print(
        f"SCREEN x={frame.origin.x:.0f} y={frame.origin.y:.0f} "
        f"w={frame.size.width:.0f} h={frame.size.height:.0f}"
    )

windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly
    | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID,
)
for window in windows:
    if window.get("kCGWindowLayer") == 0:
        bounds = window["kCGWindowBounds"]
        print(
            f"{window.get('kCGWindowOwnerName', '?'):20s} "
            f"x={bounds['X']:>6.0f} y={bounds['Y']:>6.0f} "
            f"w={bounds['Width']:>6.0f} h={bounds['Height']:>6.0f}"
        )
