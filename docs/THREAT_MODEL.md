# 脅威モデル

## Scope

Lid Awakeは、ログイン済みユーザーが明示操作した間だけ、電源接続中のMacBookで蓋閉じスリープを阻止します。
macOSの認証、画面ロック、FileVault、ネットワーク、ChatGPTの認証や可用性は変更しません。

## 保護対象

- macOSの通常のsleep設定へ確実に戻れること
- root helperが固定された操作以外を実行しないこと
- helper install時に検証したbinaryと実際にinstallするbinaryが一致すること
- local user以外がlease/statusを書き換えられないこと
- credential、会話内容、telemetryを収集しないこと

## Trust boundary

| 境界 | 信頼するもの | 信頼しないもの |
|---|---|---|
| GUI → lease | ログイン済みユーザー、`0600` file | stale、malformed、未来時刻のlease |
| helper → owner process | 生存PIDと`LidAwakeApp` executable path | PID再利用、異なるexecutable |
| install | 実行中appが計算したSHA-256、root staging | 管理者認証後もuser writableなsource path |
| helper → macOS | 絶対pathの`/usr/bin/pmset` | PATH探索、任意command、無期限停止 |

## Threatと対策

| Threat | 対策 | 残余リスク |
|---|---|---|
| app crash後もsleep阻止が残る | 10秒heartbeat、30秒expiry、owner PID確認 | root helper自体が停止すると解除処理を実行できない |
| AC切断・thermal pressure | helperが3秒周期で独立判定し`disablesleep 0` | OS/hardwareが状態を通知しない故障 |
| install時のhelper差し替え | root staging後にSHA-256を再検証してからinstall | 既に実行中app processが侵害されている場合 |
| shell injection | pathのPOSIX quote、digestのlowercase hex検証、固定command | AppleScript shell経由という設計自体の複雑性 |
| `pmset` hang | 5秒timeout後にTERM、必要ならKILL | helper crashと同様、最後のOS設定は残り得る |
| lease偽装 | regular file、owner UID、`0600`、schema、freshness、PID、pathを検証 | 同一ログインユーザー権限を既に奪ったprocessを完全には排除しない |
| 偽バイナリ配布 | 公式binaryを現時点で配布しない | 利用者が第三者binaryを信頼する危険 |

## Public sourceとbinary distribution

source codeの公開と、実行バイナリの安全な配布は別問題です。source repositoryはCI、test、license、security policyを
満たして公開できます。一方、配布binaryはDeveloper ID署名、hardened runtime、notarization、stapling、clean machineでの
install/uninstall試験が完了するまでreleaseしません。

## Security regression gate

次の変更は脅威モデルの再reviewを必須とします。

- helperの権限、install方式、LaunchDaemon plist
- lease/statusのschema、owner検証、permission
- `pmset` command、timeout、signal handling
- network、telemetry、自動更新の追加
- binary signing、notarization、release workflow
