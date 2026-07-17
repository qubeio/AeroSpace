#!/bin/bash

set -euo pipefail

aerospace_bin="${AEROSPACE_BIN:-$(command -v aerospace)}"
processes=()

for token in "$@"; do
    if [[ ! "$token" =~ ^[0-9]+:[0-9]+$ ]]; then
        echo "invalid test-window token: $token" >&2
        exit 2
    fi
    window_id="${token%%:*}"
    process_id="${token#*:}"
    "$aerospace_bin" close --window-id "$window_id" >/dev/null 2>&1 || true
    processes+=("$process_id")
done

sleep 1
for process_id in "${processes[@]-}"; do
    [[ -z "$process_id" ]] && continue
    kill -TERM "$process_id" >/dev/null 2>&1 || true
done

for _ in {1..20}; do
    alive=false
    for process_id in "${processes[@]-}"; do
        [[ -z "$process_id" ]] && continue
        if kill -0 "$process_id" >/dev/null 2>&1; then
            alive=true
            break
        fi
    done
    [[ "$alive" == false ]] && break
    sleep 0.25
done

find /tmp -maxdepth 1 -name 'wmtest-*.txt' -delete

for process_id in "${processes[@]-}"; do
    [[ -z "$process_id" ]] && continue
    if kill -0 "$process_id" >/dev/null 2>&1; then
        echo "TextEdit process $process_id did not exit" >&2
        exit 1
    fi
done
