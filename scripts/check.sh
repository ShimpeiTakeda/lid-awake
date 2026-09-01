#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
cd "$repo_dir"

for script in scripts/*.sh; do
  zsh -n "$script"
done
swift format lint --recursive --strict Sources Tests Package.swift
swift test
./scripts/build-app.sh
./scripts/audit-app.sh
./scripts/audit-source.sh
