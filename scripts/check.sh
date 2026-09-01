#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
cd "$repo_dir"

swift format lint --recursive --strict Sources Tests Package.swift
swift test
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 'dist/Lid Awake.app'
plutil -lint 'dist/Lid Awake.app/Contents/Info.plist'
plutil -lint Resources/com.takedashinpei.lidawake.helper.plist
