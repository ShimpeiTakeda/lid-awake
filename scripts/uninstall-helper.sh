#!/bin/zsh
set -euo pipefail

sudo launchctl bootout system/com.takedashinpei.lidawake.helper 2>/dev/null || true
sudo pmset -a disablesleep 0
sudo rm -f /Library/PrivilegedHelperTools/com.takedashinpei.lidawake.helper
sudo rm -f /Library/LaunchDaemons/com.takedashinpei.lidawake.helper.plist

echo 'Lid Awake helperを削除し、通常のスリープ設定へ戻しました。'
