# 実機検証手順

## 目的

蓋を閉じたMacBook上でChatGPTが動作を続け、別ネットワークのiPhoneからRemoteを利用できることと、終了時に通常のスリープ設定へ戻ることを検証します。

## 前提条件

- MacBookを電源へ接続します。
- MacとiPhoneを同じChatGPTアカウントおよびworkspaceへ接続します。
- MacでChatGPTとLid Awakeを起動します。
- Macを机など放熱できる場所へ置きます。鞄、布団、ソファでは実行しません。

## 常時起動の確認

1. Lid Awakeで「常時起動を開始」を押します。
2. 画面が赤い「常時起動中」になり、電源・ChatGPT・安全監視がすべて正常表示になることを確認します。
3. Macで次を実行し、`SleepDisabled 1`を確認します。

   ```bash
   pmset -g | grep SleepDisabled
   ```

4. MacBookの蓋を完全に閉じ、2分待ちます。
5. iPhoneのWi-Fiを切り、4Gまたは5Gへ切り替えます。
6. ChatGPTモバイルアプリのRemoteから対象Macを選び、既存threadへの送信または新規threadの開始が成功することを確認します。

## 安全解除の確認

1. 蓋を開き、Lid Awakeの「通常モードに戻す」を押すか、アプリを終了します。
2. 30秒以内に次の出力が`SleepDisabled 0`になることを確認します。

   ```bash
   pmset -g | grep SleepDisabled
   ```

## Hard failと復旧

- Lid Awakeがエラーを表示した場合、蓋を閉じません。
- `SleepDisabled 1`のまま通常モードへ戻らない場合は、次を実行して管理者認証を行います。

  ```bash
  sudo pmset -a disablesleep 0
  ```

- AC切断、`thermalState`が`serious`または`critical`、helper応答停止のいずれかを検出した場合は検証を中止します。
- 1回の接続成功は基本機能の確認です。旅行中の連続利用を判断する場合は、同じ条件で一晩以上の試験を別途行います。

## 2026-09-01 実測

- 蓋を閉じて2分後、iPhoneをWi-Fiから4Gへ切り替えた状態でChatGPT Remoteの操作に成功しました。
- 検証後のMac側は`SleepDisabled 1`、helper statusは`schemaVersion 2`、`reason active`、`isBlockingSleep true`、thermal stateは`nominal`でした。
- アプリ正常終了後に`SleepDisabled 0`へ戻ることも確認しました。
