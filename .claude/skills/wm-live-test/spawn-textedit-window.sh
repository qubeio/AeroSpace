#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <workspace> <sequence>" >&2
    exit 2
fi

workspace="$1"
sequence="$2"
if [[ ! "$sequence" =~ ^[0-9]+$ ]]; then
    echo "sequence must be a non-negative integer" >&2
    exit 2
fi
aerospace_bin="${AEROSPACE_BIN:-$(command -v aerospace)}"
file="/tmp/wmtest-${sequence}.txt"
title="wmtest-${sequence}.txt"

textedit_window_ids() {
    "$aerospace_bin" list-windows --all --format '%{window-id}|%{app-name}' |
        awk -F'|' '$2 == "TextEdit" { print $1 }'
}

textedit_process_ids() {
    pgrep -x TextEdit 2>/dev/null || true
}

contains() {
    local needle="$1"
    shift
    local value
    for value in "$@"; do
        [[ "$value" == "$needle" ]] && return 0
    done
    return 1
}

readarray_compat() {
    local destination="$1"
    local input="$2"
    local value
    eval "$destination=()"
    while IFS= read -r value; do
        [[ -z "$value" ]] || eval "$destination+=(\"\$value\")"
    done <<< "$input"
}

before_windows=()
before_processes=()
readarray_compat before_windows "$(textedit_window_ids)"
readarray_compat before_processes "$(textedit_process_ids)"

printf x > "$file"
open -Fn -a TextEdit "$file"

stable_samples=0
created_window=""
created_process=""
new_windows=()
new_processes=()

for _ in {1..40}; do
    after_windows=()
    after_processes=()
    candidate_windows=()
    new_windows=()
    new_processes=()

    readarray_compat after_windows "$(textedit_window_ids)"
    readarray_compat after_processes "$(textedit_process_ids)"
    readarray_compat candidate_windows "$(
        "$aerospace_bin" list-windows --workspace "$workspace" --format '%{window-id}|%{app-name}|%{window-title}' |
            awk -F'|' -v title="$title" '$2 == "TextEdit" && $3 == title { print $1 }'
    )"

    for value in "${after_windows[@]-}"; do
        [[ -z "$value" ]] || contains "$value" "${before_windows[@]-}" || new_windows+=("$value")
    done
    for value in "${after_processes[@]-}"; do
        [[ -z "$value" ]] || contains "$value" "${before_processes[@]-}" || new_processes+=("$value")
    done

    if [[ ${#new_windows[@]} -eq 1 && ${#new_processes[@]} -eq 1 &&
          ${#candidate_windows[@]} -eq 1 && "${new_windows[0]}" == "${candidate_windows[0]}" ]]; then
        if [[ "$created_window" == "${new_windows[0]}" && "$created_process" == "${new_processes[0]}" ]]; then
            stable_samples=$((stable_samples + 1))
        else
            created_window="${new_windows[0]}"
            created_process="${new_processes[0]}"
            stable_samples=1
        fi
        if [[ $stable_samples -ge 8 ]]; then
            printf '%s:%s\n' "$created_window" "$created_process"
            exit 0
        fi
    else
        stable_samples=0
        created_window=""
        created_process=""
    fi
    sleep 0.25
done

echo "TextEdit window failed to stabilize for $file on workspace $workspace" >&2
"$aerospace_bin" list-windows --all --format '%{window-id} | %{workspace} | %{app-name} | %{window-title}' >&2
for value in "${new_windows[@]-}"; do
    [[ -z "$value" ]] && continue
    "$aerospace_bin" close --window-id "$value" >/dev/null 2>&1 || true
done
for value in "${new_processes[@]-}"; do
    [[ -z "$value" ]] && continue
    kill -TERM "$value" >/dev/null 2>&1 || true
done
exit 1
