#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
cd "$repo_dir"

publishable_files=$(git ls-files --cached --others --exclude-standard)
while IFS= read -r file; do
  [[ "$file" == README.ja.md ]] && continue
  [[ "$file" == Resources/ja.lproj/* ]] && continue
  if rg -n --pcre2 '[\p{Hiragana}\p{Katakana}\p{Han}]' "$file"; then
    echo "Japanese text is outside the allowed localized files: $file" >&2
    exit 1
  fi
done <<< "$publishable_files"

echo 'canonical language audit: PASS'
