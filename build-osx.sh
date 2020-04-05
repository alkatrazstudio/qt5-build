#!/usr/bin/env bash
set -xeuo pipefail
cd "$(dirname -- "$0")"

./build-linux.sh "$@"
