#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
app_dir="$repo_dir/dist/Lid Awake.app"
info_plist="$app_dir/Contents/Info.plist"
helper="$app_dir/Contents/Library/LaunchServices/com.takedashinpei.lidawake.helper"
helper_plist="$app_dir/Contents/Resources/com.takedashinpei.lidawake.helper.plist"
english_strings="$app_dir/Contents/Resources/en.lproj/Localizable.strings"
japanese_strings="$app_dir/Contents/Resources/ja.lproj/Localizable.strings"

[[ -x "$app_dir/Contents/MacOS/LidAwakeApp" ]]
[[ -x "$helper" ]]
[[ -f "$helper_plist" ]]
[[ -f "$english_strings" ]]
[[ -f "$japanese_strings" ]]

[[ $(plutil -extract CFBundleDevelopmentRegion raw "$info_plist") == en ]]
[[ $(plutil -extract CFBundleIdentifier raw "$info_plist") == com.takedashinpei.lidawake ]]
[[ $(plutil -extract CFBundleExecutable raw "$info_plist") == LidAwakeApp ]]
[[ $(plutil -extract LSMinimumSystemVersion raw "$info_plist") == 14.0 ]]
[[ $(plutil -extract CFBundleShortVersionString raw "$info_plist") == 0.3.0 ]]
[[ $(plutil -extract CFBundleVersion raw "$info_plist") == 4 ]]
[[ $(plutil -extract Label raw "$helper_plist") == com.takedashinpei.lidawake.helper ]]
[[ $(plutil -extract ProgramArguments.0 raw "$helper_plist") == /Library/PrivilegedHelperTools/com.takedashinpei.lidawake.helper ]]
[[ $(plutil -extract CFBundleLocalizations.0 raw "$info_plist") == en ]]
[[ $(plutil -extract CFBundleLocalizations.1 raw "$info_plist") == ja ]]

codesign --verify --deep --strict --verbose=2 "$app_dir"
codesign --verify --strict --verbose=2 "$helper"
plutil -lint "$info_plist"
plutil -lint "$helper_plist"
plutil -lint "$english_strings"
plutil -lint "$japanese_strings"

actual_files=$(cd "$app_dir" && find Contents -type f | LC_ALL=C sort)
expected_files=$'Contents/Info.plist\nContents/Library/LaunchServices/com.takedashinpei.lidawake.helper\nContents/MacOS/LidAwakeApp\nContents/Resources/com.takedashinpei.lidawake.helper.plist\nContents/Resources/en.lproj/Localizable.strings\nContents/Resources/ja.lproj/Localizable.strings\nContents/_CodeSignature/CodeResources'
[[ "$actual_files" == "$expected_files" ]]

echo 'app bundle audit: PASS'
