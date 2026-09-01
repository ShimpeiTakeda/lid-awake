#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
cd "$repo_dir"

source_files=$(git ls-files --cached --others --exclude-standard)

if print -r -- "$source_files" | rg '(^|/)(\.DS_Store|\.build|dist)(/|$)'; then
  echo 'A local artifact is present in the publishable file set' >&2
  exit 1
fi

secret_pattern='(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY)'
while IFS= read -r file; do
  [[ "$file" == scripts/audit-source.sh ]] && continue
  if rg -n --regexp "$secret_pattern" "$file"; then
    echo "A secret-like value is present in a publishable file: $file" >&2
    exit 1
  fi
done <<< "$source_files"

while IFS= read -r file; do
  size=$(stat -f %z "$file")
  if (( size > 1048576 )); then
    echo "A publishable file exceeds 1 MiB: $file ($size bytes)" >&2
    exit 1
  fi
done <<< "$source_files"

echo 'source audit: PASS'
