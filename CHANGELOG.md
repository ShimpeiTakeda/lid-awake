# Changelog

このprojectは[Semantic Versioning](https://semver.org/)に従います。

## Unreleased

## 0.2.0 - 2026-09-01

### Security

- privileged helperをroot所有の一時領域へstageし、SHA-256検証後にだけsystem pathへinstallするようにしました。
- `pmset`の実行に5秒のtimeoutを設け、停止したprocessを終了してfail-safeへ移るようにしました。

### Tests

- leaseの全拒否条件、境界時刻、failure precedenceを検証します。
- sleep状態遷移、secure JSON file、process timeout、installer command injection耐性を検証します。

## 0.1.1 - 2026-09-01

- `pmset`適用後の`SleepDisabled`を確認し、確認失敗時に安全側遷移を再試行するようにしました。

## 0.1.0 - 2026-09-01

- AC接続中に限る蓋閉じ常時起動、30秒lease、thermal safety stopを実装しました。
