# AeroSpace design notes

Implementation tasks are tracked in Linear: **[AeroSpace](https://linear.app/qubeio/project/aerospace)**

This directory holds historical design documents and reference material only — not the task index.

## Start here

1. **[QUB-32 — design & mapping](QUB-32-bsp-komorebi-design.md)** — sign-off gate (this doc)
2. Implementation issues [QUB-33](https://linear.app/qubeio/issue/QUB-33) … [QUB-43](https://linear.app/qubeio/issue/QUB-43) on Linear

## Local komorebi reference

Clone for reading upstream code (not a submodule):

```text
/Users/andreas.frangopoulos/source/repos/komorebi-for-mac
```

Layout geometry crate (git dependency, rev `24c0ce0` in `komorebi-for-mac/Cargo.toml`) appears under Cargo checkouts after `cargo fetch`:

```text
~/.cargo/git/checkouts/komorebi-af3d9505330cd7a9/24c0ce0/komorebi-layouts/
```
