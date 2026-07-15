# Build Environment Notes

This file documents known environment issues and their fixes for macOS 27 / Xcode 26 beta / Swift 6.2.
It exists because the build is sensitive to toolchain versions and several things broke simultaneously on this stack.

## Known Issues and Fixes

### 1. `-warnings-as-errors` conflicts with `-suppress-warnings` in Swift 6.2

**Symptom:**
```
error: conflicting options '-warnings-as-errors' and '-suppress-warnings'
error: SwiftDriver InternalCollectionsUtilities normal x86_64 ... failed
```

**Root cause:**
When `swift build --arch arm64 --arch x86_64` builds a universal binary it uses the Xcode-compatible SPM
backend. That backend automatically adds `-suppress-warnings` to third-party package builds (standard
Xcode behaviour to silence package warnings). In Swift 6.2, `-warnings-as-errors` and
`-suppress-warnings` became mutually exclusive — previously `-suppress-warnings` silently won, now it's a
hard error. `-Xswiftc` flags are blunt: they apply to every compilation unit including packages, so you
cannot use `-Xswiftc -warnings-as-errors` with the universal build backend.

**Fix applied:**
- Removed `-Xswiftc -warnings-as-errors` from the `swift build` CLI step in `build-release.sh`.
- Changed CLI build to use `--build-path .build-cli` (separate directory) so it doesn't contaminate
  the `.build/out` package cache used by `xcodebuild`.
- Removed `SWIFT_TREAT_WARNINGS_AS_ERRORS` / `GCC_TREAT_WARNINGS_AS_ERRORS` from `project.yml` (and
  regenerated `AeroSpace.xcodeproj/project.pbxproj`) to prevent xcodebuild from also triggering the
  conflict.

Code quality is still enforced by `./format.sh` (swiftformat + swiftlint) and `./run-tests.sh`.

---

### 2. Codesign failure — missing private key for Developer ID certificate

**Symptom:**
```
error: Missing private key for signing certificate. Failed to locate the private key matching
certificate "Developer ID Application: ANDREAS FRANGOPOULQS (KHDG39GW8U)" in the keychain.
```

**Root cause:**
`Developer ID Application` certificates are for App Store / notarized distribution. The private key
lives in the certificate holder's keychain export (`.p12`). A fresh dev machine won't have it.

**Fix:**
Find your available signing identity:
```bash
security find-identity -v -p codesigning
```

Then build with it:
```bash
./build-release.sh --codesign-identity "Apple Development: ANDREAS FRANGOPOULQS (675TYHQ752)"

# Or via Taskfile:
task build:release CODESIGN_IDENTITY="Apple Development: ANDREAS FRANGOPOULQS (675TYHQ752)"
```

The app will be signed for local testing (not notarized). macOS may show a first-run prompt for
Accessibility permission — that's expected.

---

### 3. Ruby 4.0 — `cannot load such file -- logger`

**Symptom:**
```
cannot load such file -- logger (LoadError)
```
or
```
bundler: command not found: asciidoctor
```

**Root cause:**
Homebrew ships Ruby 4.0 on macOS 27. Two changes broke the doc build:
- The old `Gemfile` pinned `ruby '~> 3.0'` — updated to `'>= 3.0'`.
- In Ruby 4.0, `logger` is no longer a default gem; `asciidoctor` requires it explicitly.

**Fix applied in `Gemfile`:**
```ruby
ruby '>= 3.0'
gem 'logger'  # no longer a default gem in Ruby 4.0
```

---

### 4. Java not found (`Unable to locate a Java Runtime`)

**Symptom:**
```
Unable to locate a Java Runtime
```
during `./build-shell-completion.sh` / ANTLR parser generation.

**Root cause:**
Homebrew's `openjdk` is keg-only — it is NOT symlinked into `/usr/bin`. The script's PATH whitelist
(`.deps/bin:/bin:/usr/bin`) doesn't include the Homebrew keg path. `add-optional-dep-to-bin java`
uses `/usr/bin/which java` which finds the macOS stub at `/usr/bin/java` — that stub only launches
a download dialog and exits non-zero.

**Fix applied in `script/setup.sh`:**
```bash
# Java is keg-only in Homebrew (not symlinked into /usr/bin), so check the keg path directly
if /bin/test -f /opt/homebrew/opt/openjdk/bin/java; then
    /bin/cat > ".deps/bin/java" <<EOF
#!/bin/bash
exec '/opt/homebrew/opt/openjdk/bin/java' "\$@"
EOF
fi
```

---

## Taskfile Notes

The `Taskfile.yml` has a `CODESIGN_IDENTITY` variable (empty by default). Set it to skip the
`Developer ID Application` requirement:

```bash
task build:release CODESIGN_IDENTITY="Apple Development: ANDREAS FRANGOPOULQS (675TYHQ752)"
task install:release CODESIGN_IDENTITY="Apple Development: ANDREAS FRANGOPOULQS (675TYHQ752)"
```

`task clean` removes `.build-cli` (the isolated CLI build directory) in addition to the standard
`.build .debug .release .xcode-build`.
