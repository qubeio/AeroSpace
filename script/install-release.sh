#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

app_name="${APP_NAME:-AeroSpace}"
cli_name="${CLI_NAME:-aerospace}"
release_dir="${RELEASE_DIR:-.release}"
install_path="${INSTALL_PATH:-/Applications/$app_name.app}"
cli_install_path="${CLI_INSTALL_PATH:-/usr/local/bin/$cli_name}"
privilege_command="${PRIVILEGE_COMMAND-sudo}"
skip_quit="${AEROSPACE_INSTALL_SKIP_QUIT:-0}"

release_app="$release_dir/$app_name.app"
release_app_binary="$release_app/Contents/MacOS/$app_name"
release_cli="$release_dir/$cli_name"

transaction_id="$$"
app_stage="$install_path.aerospace-new.$transaction_id"
app_backup="$install_path.aerospace-old.$transaction_id"
cli_stage="$cli_install_path.aerospace-new.$transaction_id"
cli_backup="$cli_install_path.aerospace-old.$transaction_id"

app_backed_up=0
cli_backed_up=0
app_installed=0
cli_installed=0
committed=0

privileged() {
    if test -n "$privilege_command"; then
        "$privilege_command" "$@"
    else
        "$@"
    fi
}

app_identifier() {
    "$1/Contents/MacOS/$app_name" --version
}

cli_identifier() {
    "$1" --version 2>/dev/null | sed -n 's/^aerospace CLI client version: //p' | head -n 1
}

cleanup_paths() {
    rm -rf "$app_stage"
    privileged rm -f "$cli_stage"
}

rollback() {
    local original_exit=$?

    if test "$committed" = 1; then
        return
    fi

    set +e
    echo "Installation failed; restoring the previous app and CLI." >&2

    if test "$cli_installed" = 1; then
        privileged rm -f "$cli_install_path"
    fi
    if test "$app_installed" = 1; then
        rm -rf "$install_path"
    fi
    if test "$cli_backed_up" = 1; then
        privileged mv "$cli_backup" "$cli_install_path"
    fi
    if test "$app_backed_up" = 1; then
        mv "$app_backup" "$install_path"
    fi
    cleanup_paths

    echo "Recovery command: (cd '$PWD' && task install:release)" >&2
    exit "$original_exit"
}

trap rollback EXIT
trap 'exit 130' INT TERM HUP

if ! test -x "$release_app_binary"; then
    echo "Missing executable release app: $release_app_binary" >&2
    exit 1
fi
if ! test -x "$release_cli"; then
    echo "Missing executable release CLI: $release_cli" >&2
    exit 1
fi

release_app_identifier="$(app_identifier "$release_app")"
release_cli_identifier="$(cli_identifier "$release_cli")"
if test -z "$release_cli_identifier" || test "$release_app_identifier" != "$release_cli_identifier"; then
    echo "Release app and CLI build identifiers do not match:" >&2
    echo "  app: $release_app_identifier" >&2
    echo "  CLI: ${release_cli_identifier:-unknown}" >&2
    exit 1
fi

if test -n "$privilege_command"; then
    echo "Validating privileged access before changing the installation."
    privileged -v
fi

cleanup_paths
echo "Staging release app and CLI."
cp -R "$release_app" "$app_stage"
privileged install -m 0755 "$release_cli" "$cli_stage"

if test "$(/usr/bin/stat -f '%Lp' "$cli_stage")" != 755; then
    echo "Staged CLI does not have mode 0755: $cli_stage" >&2
    exit 1
fi
if test "$(app_identifier "$app_stage")" != "$(cli_identifier "$cli_stage")"; then
    echo "Staged app and CLI build identifiers do not match." >&2
    exit 1
fi

if test "$skip_quit" != 1; then
    osascript -e "quit app \"$app_name\"" || true
    sleep 1
fi

if test -e "$install_path"; then
    mv "$install_path" "$app_backup"
    app_backed_up=1
fi
if privileged test -e "$cli_install_path"; then
    privileged mv "$cli_install_path" "$cli_backup"
    cli_backed_up=1
fi

mv "$app_stage" "$install_path"
app_installed=1
privileged mv "$cli_stage" "$cli_install_path"
cli_installed=1

installed_app_identifier="$(app_identifier "$install_path")"
installed_cli_identifier="$(cli_identifier "$cli_install_path")"
if test -z "$installed_cli_identifier" || test "$installed_app_identifier" != "$installed_cli_identifier"; then
    echo "Installed app and CLI build identifiers do not match:" >&2
    echo "  app: $installed_app_identifier" >&2
    echo "  CLI: ${installed_cli_identifier:-unknown}" >&2
    exit 1
fi
if test "$(/usr/bin/stat -f '%Lp' "$cli_install_path")" != 755; then
    echo "Installed CLI does not have mode 0755: $cli_install_path" >&2
    exit 1
fi

committed=1
trap - EXIT INT TERM HUP

rm -rf "$app_backup"
privileged rm -f "$cli_backup"

echo "Installed $app_name and $cli_name build $installed_app_identifier."
echo "AeroSpace remains stopped; start it when ready."
