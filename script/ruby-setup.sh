#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ensure_rbenv() {
    if command -v rbenv >/dev/null 2>&1; then
        eval "$(rbenv init - bash)"
        return 0
    fi
    if [[ -x /opt/homebrew/bin/rbenv ]]; then
        eval "$(/opt/homebrew/bin/rbenv init - bash)"
        return 0
    fi
    if [[ -x "${HOME}/.rbenv/bin/rbenv" ]]; then
        eval "$("${HOME}/.rbenv/bin/rbenv" init - bash)"
        return 0
    fi
    return 1
}

if ! ensure_rbenv; then
    if command -v brew >/dev/null 2>&1; then
        echo "Installing rbenv and ruby-build via Homebrew..."
        brew install rbenv ruby-build
        eval "$(rbenv init - bash)"
    else
        echo "rbenv not found and Homebrew not in PATH." >&2
        echo "Install: brew install rbenv ruby-build" >&2
        echo "Then add to ~/.zshrc: eval \"\$(rbenv init - zsh)\"" >&2
        exit 1
    fi
fi

rbenv install -s 3.4.7
echo "Using $(command -v ruby) — $(ruby -v)"
gem install bundler -v 2.7.2
bundle install
echo "Ruby toolchain ready for AeroSpace builds."
