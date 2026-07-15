# AeroSpace [![Build](https://github.com/qubeio/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/qubeio/AeroSpace/actions/workflows/build.yml)

<img src="./resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" align="right">

AeroSpace is an i3-like tiling window manager for macOS.

This repository is **[qubeio's fork](https://github.com/qubeio/AeroSpace)** of the upstream project by [nikitabobko/AeroSpace](https://github.com/nikitabobko/AeroSpace). We track upstream closely and add features on top. For the original project, community, and releases, see the [upstream repository](https://github.com/nikitabobko/AeroSpace).

## Fork changes

- **BSP layout mode** — komorebi-inspired binary space partitioning as an alternative to the default tiles layout (`layout bsp`, configurable via `[bsp]` in config)
- **Bundle ID** — `com.qubeio.aerospace` (debug: `com.qubeio.aerospace.debug`), so this fork can run alongside upstream AeroSpace
- **Task tracking** — development work is tracked in Linear: [AeroSpace project](https://linear.app/qubeio/project/aerospace)

See [PRD.md](./PRD.md) for architecture and fork goals.

## Key features

- Tiling window manager based on a [tree paradigm](https://nikitabobko.github.io/AeroSpace/guide#tree)
- [i3](https://i3wm.org/) inspired
- Fast workspaces switching without animations and without the necessity to disable SIP
- AeroSpace employs its [own emulation of virtual workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces) instead of relying on native macOS Spaces due to [their considerable limitations](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces)
- Plain text configuration (dotfiles friendly). See: [default-config.toml](https://nikitabobko.github.io/AeroSpace/guide#default-config)
- CLI first (manpages and shell completion included)
- Doesn't require disabling SIP (System Integrity Protection)
- [Proper multi-monitor support](https://nikitabobko.github.io/AeroSpace/guide#multiple-monitors) (i3-like paradigm)

## Installation

There is no Homebrew cask for this fork yet. Build from source:

```bash
git clone https://github.com/qubeio/AeroSpace.git
cd AeroSpace
./build-debug.sh   # or ./build-release.sh
./run-debug.sh     # launch debug build
```

Setup details (dependencies, codesign certificate, tests): [dev-docs/development.md](./dev-docs/development.md)

In multi-monitor setup please make sure that monitors [are properly arranged](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement).

For a pre-built binary without building locally, use upstream's [Homebrew cask](https://nikitabobko.github.io/AeroSpace/guide#installation) — note that upstream and this fork use different bundle IDs and can coexist.

> [!NOTE]
> Like upstream, this fork is not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution). You may need to remove the quarantine attribute after download, or allow the app in System Settings.

## Documentation

Upstream docs cover most behavior (commands, config, workspaces):

- [AeroSpace Guide](https://nikitabobko.github.io/AeroSpace/guide)
- [AeroSpace Commands](https://nikitabobko.github.io/AeroSpace/commands)
- [AeroSpace Goodies](https://nikitabobko.github.io/AeroSpace/goodies)

Fork-specific design notes live under [tasks/](./tasks/) and [PRD.md](./PRD.md).

Demo videos (upstream):

- [YouTube 91 sec Demo](https://www.youtube.com/watch?v=UOl7ErqWbrk)
- [YouTube Guide by Josean Martinez](https://www.youtube.com/watch?v=-FoWClVHG5g)

## Development

- [dev-docs/development.md](./dev-docs/development.md) — build, test, and debug
- [CLAUDE.md](./CLAUDE.md) — agent and contributor workflow (Linear issues, conventions)
- [CONTRIBUTING.md](./CONTRIBUTING.md) — contribution guidelines (adapted from upstream)

Quick commands:

```bash
make build    # ./build-debug.sh
make test     # full test + lint pipeline
make format   # swiftformat + swiftlint
```

## Upstream

This fork is based on [nikitabobko/AeroSpace](https://github.com/nikitabobko/AeroSpace). Report bugs and feature ideas for **upstream AeroSpace** via [GitHub Discussions](https://github.com/nikitabobko/AeroSpace/discussions) (see upstream [CONTRIBUTING.md](https://github.com/nikitabobko/AeroSpace/blob/main/CONTRIBUTING.md)).

To sync with upstream:

```bash
git fetch upstream
git merge upstream/main
```

## macOS compatibility table

|                                                                                | macOS 13 (Ventura) | macOS 14 (Sonoma) | macOS 15 (Sequoia) | macOS 26 (Tahoe) |
| ------------------------------------------------------------------------------ | ------------------ | ----------------- | ------------------ | ---------------- |
| AeroSpace binary runs on ...                                                   | +                  | +                 | +                  | +                |
| AeroSpace debug build from sources is supported on ...                         |                    | +                 | +                  | +                |
| AeroSpace release build from sources is supported on ... (Requires Xcode 26+)  |                    |                   | +                  | +                |

## Tip of the day

```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```

Now, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

## Related projects

- [Amethyst](https://github.com/ianyh/Amethyst)
- [yabai](https://github.com/koekeishiya/yabai)
- [komorebi](https://github.com/LGUG2Z/komorebi) — inspiration for BSP layout in this fork
