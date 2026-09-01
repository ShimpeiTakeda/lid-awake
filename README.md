# Lid Awake

MacBookを電源接続中に限り、蓋を閉じても起動状態に保つmacOSアプリです。iPhone版ChatGPTのRemoteから、
Mac上のChatGPT/Codexへ接続する用途を想定しています。

> [!WARNING]
> root helperがmacOSの`pmset -a disablesleep`を変更します。鞄、布団、ソファなど放熱できない場所では
> 使用しないでください。署名・notarize済みの公式バイナリはまだ配布していません。

## 挙動

- 緑の「通常モード」: macOS標準のスリープ動作です。
- 赤の「常時起動中」: 蓋を閉じてもMacが動作を続けます。
- 黄の「安全停止」: AC切断または重大な熱状態を検出し、通常モードへ戻っています。
- 1つの大きなボタンで開始・終了します。再起動後に自動で有効化しません。

色だけに依存せず、状態名・説明・アイコンを併記します。

## Safety contract

- 常時起動はAC接続中だけ許可します。
- GUIアプリは10秒ごとに`0600`のleaseを更新します。
- helperはleaseが30秒以上更新されない、owner processが終了した、ACが外れた、または
  macOSのthermal stateが`serious`以上になった場合、`pmset -a disablesleep 0`を実行します。
- helper起動時、アプリ終了時、アンインストール時は通常モードへ戻します。
- `pmset`は5秒でtimeoutし、適用後の`SleepDisabled`が期待値と一致した場合だけ成功とします。
- 再起動後に常時起動を自動復元しません。
- 画面ロックや認証を解除・迂回しません。
- network通信、telemetry、credentialやChatGPT会話内容の読取・保存を行いません。

詳細は[behavior contract](docs/BEHAVIOR_CONTRACT.md)、[architecture](docs/ARCHITECTURE.md)、
[脅威モデル](docs/THREAT_MODEL.md)を参照してください。

## Requirements

- macOS 14以降
- Apple Silicon MacBook
- Swift 6 / Xcode Command Line Tools
- AC電源

Intel Macは対象外です。現時点のCIと実機証拠はApple Siliconだけです。

## Build and test

```bash
git clone https://github.com/ShimpeiTakeda/lid-awake.git
cd lid-awake
./scripts/check.sh
open 'dist/Lid Awake.app'
```

`check.sh`はformat、35件以上のunit/integration test、release build、ad-hoc code signature、bundle/plist、
tracked sourceのsecret・local artifact・大容量file監査を実行します。

初回に「常時起動を開始」を押すと、helper登録のためmacOSの管理者認証が1回表示されます。管理者認証前に
helperとplistのSHA-256を取得し、root所有のstaging領域へcopyした内容と一致した場合だけsystem pathを更新します。

## Verification

自動testはrootの`pmset`を変更しません。蓋閉じとiPhone版ChatGPT Remoteを含む確認は
[実機検証手順](docs/VERIFICATION.md)に従います。過去の実測は新しいcommitの検証証拠ではありません。
testの責務分離は[test strategy](docs/TEST_STRATEGY.md)に記載しています。

## Uninstall

まずLid Awakeを通常モードに戻して終了し、次を実行します。

```bash
./scripts/uninstall-helper.sh
```

その後、`dist/Lid Awake.app`または`/Applications/Lid Awake.app`を削除します。

## Limitations

- このアプリが保証するのはMacのスリープ阻止までです。Wi-Fi、インターネット、OpenAI、
  ChatGPT/Codexアプリの生存は別の可用性条件です。
- FileVault有効環境で再起動した場合、ローカルログイン前にRemoteを復旧できません。
- 同一ログインユーザー権限を既に奪ったprocessによるlease偽装を完全には排除しません。
- 現在のlocal buildはad-hoc署名です。Developer ID署名とnotarizationが完了するまで実行バイナリをreleaseしません。

source公開とbinary配布のgateは[release checklist](docs/RELEASE_CHECKLIST.md)で分離しています。

## Contributing and security

- 変更方法: [CONTRIBUTING.md](CONTRIBUTING.md)
- 脆弱性報告: [SECURITY.md](SECURITY.md)
- 行動規範: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 変更履歴: [CHANGELOG.md](CHANGELOG.md)

## Design reference

蓋閉じスリープの阻止方法とfail-safe設計は、MITライセンスの
[Adrafinil](https://github.com/kageroumado/adrafinil)を参照しています。本repositoryは別実装であり、
AI agent連携や無期限の永続設定は持ちません。

## License

[MIT License](LICENSE)
