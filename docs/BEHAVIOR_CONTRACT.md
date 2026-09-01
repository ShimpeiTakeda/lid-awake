# Behavior contract

この文書はrefactorやsecurity hardeningで変えてはいけない利用者向け挙動を固定します。変更する場合は、code変更より
先にIssueとこの文書を更新し、変更理由とmigrationを合意します。

## Main journey

1. ユーザーがLid Awakeをdouble clickすると、単一windowと大きなbuttonが表示されます。
2. 通常時は緑の「通常モード」で、蓋を閉じるとmacOS標準どおりsleepします。
3. AC接続中にbuttonを押すと、初回だけ管理者認証を経て開始します。
4. helperが`SleepDisabled 1`を確認した後だけ、赤の「常時起動中」を表示します。
5. もう一度buttonを押すと`SleepDisabled 0`を確認し、緑の「通常モード」へ戻ります。
6. app終了時はdisabled leaseを書き、30秒以内に通常モードへ戻ります。

## Safety journey

| 条件 | 利用者に見える結果 | helperの結果 |
|---|---|---|
| AC未接続で開始 | 黄の安全停止、接続要求 | sleepを阻止しない |
| 常時起動中にAC切断 | 黄の安全停止 | 3秒周期で`disablesleep 0` |
| thermal state serious/critical | 黄の安全停止 | 3秒周期で`disablesleep 0` |
| app crash/kill | appは消える | lease expiry後30秒以内に解除 |
| helper statusが10秒超stale | 赤を維持せずerror | 実状態は名乗らない |
| `pmset`失敗・timeout・確認不一致 | error | 状態を不明にし、解除を再試行 |
| Mac再起動 | 自動で常時起動しない | startup時に解除後、stale leaseを拒否 |

## Accessibility contract

- 色だけで状態を表現せず、状態名、説明、iconを併記します。
- buttonのlabelだけで実行結果が分かる文言を使います。
- 常時起動の成功を押下直後のlocal stateで推測せず、helperの実状態確認後に表示します。

## Non-goals

- Wi-Fi、internet、OpenAI、ChatGPT/Codexの可用性保証
- battery駆動での蓋閉じ常時起動
- 自動ログイン、画面ロック、FileVaultの迂回
- reboot後の自動復元
- network通信、telemetry、自動更新
