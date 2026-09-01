# Architecture

## 目的

ユーザーがアプリを起動し、1つの大きなボタンで常時起動を開始・終了できることを目的とします。
常時起動はアプリの生存期間に限定し、設定をOSへ放置しません。

## コンポーネント

1. `LidAwakeApp`
   - SwiftUIの単一ウィンドウです。
   - 10秒ごとに`0600`のleaseを更新します。
   - helperの実状態を読み、確認後にだけ赤の「常時起動中」を表示します。
2. `LidAwakeHelper`
   - rootのLaunchDaemonです。
   - lease、owner PID、AC、thermal stateを3秒ごとに評価します。
   - 状態遷移時だけ`pmset -a disablesleep 1|0`を実行します。
   - `pmset`は5秒でtimeoutし、適用後の実状態が一致した場合だけ遷移成功とします。
3. `LidAwakeShared`
   - lease、status、純粋な安全判定を所有します。

## 状態所有

- UI表示の正本はhelperの`status.json`です。
- 常時起動要求の正本はアプリが更新する`lease.json`です。
- 実際のスリープ阻止の正本はmacOSの`pmset`です。
- 適用確認は`pmset -g`の`SleepDisabled`を読みます。`pmset -g custom`にはこの値が出ないため使用しません。
- UIのローカルなboolだけで「常時起動中」を名乗りません。

## Failure mode

| Failure | 応答 |
|---|---|
| アプリ正常終了 | disabled leaseを書き、helperが解除 |
| アプリ強制終了・クラッシュ | 30秒でlease期限切れ、helperが解除 |
| AC切断 | 3秒以内にhelperが解除 |
| thermal state serious/critical | 3秒以内にhelperが解除 |
| helper再起動 | 起動直後に解除してからfresh leaseを再評価 |
| Mac再起動 | 過去のleaseはowner不在で拒否し、通常モード |
| status stale | UIは赤表示を継続せずエラー表示 |
| `pmset`適用・確認失敗 | 状態を不明に戻し、次の安全側遷移で必ず`disablesleep 0`を再実行 |
| `pmset`が5秒以内に終了しない | processを終了し、適用失敗として上と同じ安全側遷移へ移る |

## Privileged install

GUIは管理者認証を要求する前にbundle内のhelperとLaunchDaemon plistのSHA-256を計算します。root shellは
両fileをroot所有の`/var/tmp/lid-awake-install.*`へstageし、digest一致後にだけ既存helperを停止して
`/Library`配下を更新します。source pathからsystem pathへ直接copyしません。stagingは成功・失敗・signalの
いずれでも個別fileを削除してdirectoryを除去します。

これはuser writableなsourceが認証後に差し替えられるTOCTOUを縮小しますが、Appleの正式な
`SMAppService`とcode-signing requirementによるcaller認証の代替ではありません。配布binaryを出す前の
残作業は[release checklist](RELEASE_CHECKLIST.md)を正本とします。

helperの安全契約を変えたreleaseではstatus schemaを更新します。旧helperのstatusを新appが受理せず、次回開始時に
管理者認証を伴う再installへ進めるためです。

## Non-goals

- Wi-FiやOpenAIサービスの可用性保証
- FileVaultログインの自動化
- App Store配布
- Developer ID署名・notarize前のbinary配布
- 自動ログインや画面ロックの回避
- バッテリー駆動での蓋閉じ常時起動
