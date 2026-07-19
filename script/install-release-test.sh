#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-install-test.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

installer="$PWD/script/install-release.sh"
privilege_wrapper="$fixture_root/privileged"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

write_app() {
    local path="$1"
    local identifier="$2"

    mkdir -p "$path/Contents/MacOS"
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$identifier" > "$path/Contents/MacOS/AeroSpace"
    chmod 0755 "$path/Contents/MacOS/AeroSpace"
}

write_cli() {
    local path="$1"
    local identifier="$2"

    printf '#!/bin/sh\nprintf "aerospace CLI client version: %%s\\n" "%s"\nprintf "AeroSpace.app server version: Unknown. The server is not running\\n"\n' "$identifier" > "$path"
    chmod 0755 "$path"
}

identifier_for_app() {
    "$1/Contents/MacOS/AeroSpace" --version
}

identifier_for_cli() {
    "$1" --version | sed -n 's/^aerospace CLI client version: //p'
}

assert_identifier() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    test "$actual" = "$expected" || fail "$description: expected '$expected', got '$actual'"
}

printf '%s\n' '#!/bin/bash' > "$privilege_wrapper"
printf '%s\n' 'if test "${1:-}" = -v; then exit 0; fi' >> "$privilege_wrapper"
printf '%s\n' 'if test "${FAIL_PRIVILEGED_OPERATION:-}" = install && test "${1:-}" = install; then exit 42; fi' >> "$privilege_wrapper"
printf '%s\n' 'if test "${FAIL_PRIVILEGED_OPERATION:-}" = commit-cli && test "${1:-}" = mv && [[ "${2:-}" = *.aerospace-new.* ]]; then exit 43; fi' >> "$privilege_wrapper"
printf '%s\n' 'exec "$@"' >> "$privilege_wrapper"
chmod 0755 "$privilege_wrapper"

run_installer() {
    local case_root="$1"

    env \
        RELEASE_DIR="$case_root/release" \
        INSTALL_PATH="$case_root/install/AeroSpace.app" \
        CLI_INSTALL_PATH="$case_root/bin/aerospace" \
        PRIVILEGE_COMMAND="$privilege_wrapper" \
        AEROSPACE_INSTALL_SKIP_QUIT=1 \
        "$installer"
}

prepare_case() {
    local case_root="$1"

    mkdir -p "$case_root/release" "$case_root/install" "$case_root/bin"
    write_app "$case_root/release/AeroSpace.app" "0.0.0 new-build"
    write_cli "$case_root/release/aerospace" "0.0.0 new-build"
    write_app "$case_root/install/AeroSpace.app" "0.0.0 old-build"
    write_cli "$case_root/bin/aerospace" "0.0.0 old-build"
}

success_case="$fixture_root/success"
prepare_case "$success_case"
run_installer "$success_case" > "$success_case/output" 2>&1
assert_identifier "0.0.0 new-build" "$(identifier_for_app "$success_case/install/AeroSpace.app")" "successful app install"
assert_identifier "0.0.0 new-build" "$(identifier_for_cli "$success_case/bin/aerospace")" "successful CLI install"
test "$(/usr/bin/stat -f '%Lp' "$success_case/bin/aerospace")" = 755 || fail "successful CLI mode"

fresh_case="$fixture_root/fresh"
mkdir -p "$fresh_case/release" "$fresh_case/install" "$fresh_case/bin"
write_app "$fresh_case/release/AeroSpace.app" "0.0.0 new-build"
write_cli "$fresh_case/release/aerospace" "0.0.0 new-build"
run_installer "$fresh_case" > "$fresh_case/output" 2>&1
assert_identifier "0.0.0 new-build" "$(identifier_for_app "$fresh_case/install/AeroSpace.app")" "fresh app install"
assert_identifier "0.0.0 new-build" "$(identifier_for_cli "$fresh_case/bin/aerospace")" "fresh CLI install"

stage_failure_case="$fixture_root/stage-failure"
prepare_case "$stage_failure_case"
if FAIL_PRIVILEGED_OPERATION=install run_installer "$stage_failure_case" > "$stage_failure_case/output" 2>&1; then
    fail "staged CLI installation unexpectedly succeeded"
fi
assert_identifier "0.0.0 old-build" "$(identifier_for_app "$stage_failure_case/install/AeroSpace.app")" "app after staged CLI failure"
assert_identifier "0.0.0 old-build" "$(identifier_for_cli "$stage_failure_case/bin/aerospace")" "CLI after staged CLI failure"

commit_failure_case="$fixture_root/commit-failure"
prepare_case "$commit_failure_case"
if FAIL_PRIVILEGED_OPERATION=commit-cli run_installer "$commit_failure_case" > "$commit_failure_case/output" 2>&1; then
    fail "committing the staged CLI unexpectedly succeeded"
fi
assert_identifier "0.0.0 old-build" "$(identifier_for_app "$commit_failure_case/install/AeroSpace.app")" "app after commit rollback"
assert_identifier "0.0.0 old-build" "$(identifier_for_cli "$commit_failure_case/bin/aerospace")" "CLI after commit rollback"
grep -Fq "Recovery command:" "$commit_failure_case/output" || fail "rollback output lacks recovery command"

if find "$fixture_root" -name '*.aerospace-new.*' -o -name '*.aerospace-old.*' | grep -q .; then
    fail "transaction staging or backup paths remain"
fi

echo "Transactional release install tests passed."
