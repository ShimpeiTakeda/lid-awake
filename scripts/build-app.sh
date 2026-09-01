#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
cd "$repo_dir"

swift build -c release --product LidAwakeApp
swift build -c release --product LidAwakeHelper
bin_dir=$(swift build -c release --show-bin-path)
app_dir="$repo_dir/dist/Lid Awake.app"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
mkdir -p "$app_dir/Contents/Library/LaunchServices"

install -m 755 "$bin_dir/LidAwakeApp" "$app_dir/Contents/MacOS/LidAwakeApp"
install -m 755 "$bin_dir/LidAwakeHelper" \
  "$app_dir/Contents/Library/LaunchServices/com.takedashinpei.lidawake.helper"
install -m 644 "$repo_dir/Resources/com.takedashinpei.lidawake.helper.plist" \
  "$app_dir/Contents/Resources/com.takedashinpei.lidawake.helper.plist"

plutil -create xml1 "$app_dir/Contents/Info.plist"
plutil -insert CFBundleDevelopmentRegion -string ja "$app_dir/Contents/Info.plist"
plutil -insert CFBundleExecutable -string LidAwakeApp "$app_dir/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.takedashinpei.lidawake "$app_dir/Contents/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$app_dir/Contents/Info.plist"
plutil -insert CFBundleName -string 'Lid Awake' "$app_dir/Contents/Info.plist"
plutil -insert CFBundleDisplayName -string 'Lid Awake' "$app_dir/Contents/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$app_dir/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.1.0 "$app_dir/Contents/Info.plist"
plutil -insert CFBundleVersion -string 1 "$app_dir/Contents/Info.plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$app_dir/Contents/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$app_dir/Contents/Info.plist"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
