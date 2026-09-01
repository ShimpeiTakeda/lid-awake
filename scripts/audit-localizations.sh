#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
english="$repo_dir/Resources/en.lproj/Localizable.strings"
japanese="$repo_dir/Resources/ja.lproj/Localizable.strings"

plutil -lint "$english"
plutil -lint "$japanese"

extract_keys() {
  sed -En 's/^"([^"]+)"[[:space:]]*=.*/\1/p' "$1" | LC_ALL=C sort
}

if ! diff -u <(extract_keys "$english") <(extract_keys "$japanese"); then
  echo 'English and Japanese localization keys do not match' >&2
  exit 1
fi

for localization in "$english" "$japanese"; do
  total=$(extract_keys "$localization" | wc -l | tr -d ' ')
  unique=$(extract_keys "$localization" | uniq | wc -l | tr -d ' ')
  if [[ "$total" != "$unique" ]]; then
    echo "Duplicate localization key: $localization" >&2
    exit 1
  fi
done

echo 'localization audit: PASS'
