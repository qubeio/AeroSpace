#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=setup.sh
source ./script/setup.sh

echo "ruby:  $(command -v ruby) — $(ruby -v)"
ruby -e 'abort "Need Ruby 3.x (see .ruby-version / Gemfile). Run: task ruby:setup" unless RUBY_VERSION.start_with?("3.")'
echo "bundle: $(command -v bundle) — $(bundle -v)"
echo "OK — Ruby/Bundler match doc build expectations."
