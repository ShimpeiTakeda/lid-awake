# Lid Awake

[English](README.md)

MacBookを電源接続中に限り、蓋を閉じても起動状態に保つmacOSアプリです。iPhone版ChatGPTのRemoteから、Mac上のChatGPT/Codexへ接続する用途を想定しています。

> [!WARNING]
> root helperがmacOSの`pmset -a disablesleep`を変更します。鞄、布団、ソファなど放熱できない場所では使用しないでください。署名・notarize済みの公式バイナリはまだ配布していません。

## 挙動

- **緑の「通常モード」:** 蓋を閉じるとmacOS標準どおりスリープします。
- **赤の「常時起動中」:** 蓋を閉じてもMacが動作を続けます。
- **黄の「安全停止」:** AC切断または重大な熱状態を検出し、通常モードへ戻っています。
- 1つの大きなボタンで開始・終了します。再起動後に自動で有効化しません。

色だけに依存せず、状態名、説明、アイコンを併記します。

## 安全契約

- 常時起動はAC接続中だけ許可します。
- GUIアプリは10秒ごとに`0600`のleaseを更新します。
- helperはleaseが30秒以上更新されない、owner processが終了した、ACが外れた、またはmacOSのthermal stateが`serious`以上になった場合、`pmset -a disablesleep 0`を実行します。
- helper起動時、アプリ終了時、アンインストール時は通常モードへ戻します。
- `pmset`は5秒でtimeoutし、適用後の`SleepDisabled`が期待値と一致した場合だけ成功とします。
- 画面ロック、認証、FileVaultを解除・迂回しません。
- network通信、telemetry、credentialやChatGPT会話内容の読み取り・保存を行いません。

詳細な仕様、脅威モデル、release条件は英語の[正本README](README.md)とリンク先文書を参照してください。

## 必要環境

- macOS 14以降
- Apple Silicon MacBook
- source buildにはSwift 6とXcode Command Line Tools
- 常時起動中はAC電源

## Build and test

```bash
git clone https://github.com/ShimpeiTakeda/lid-awake.git
cd lid-awake
./scripts/check.sh
open 'dist/Lid Awake.app'
```

初回に「常時起動を開始」を押すと、helper登録のためmacOSの管理者認証が1回表示されます。自動testはrootの`pmset`を変更しません。

## アンインストール

通常モードへ戻してアプリを終了し、次を実行します。

```bash
./scripts/uninstall-helper.sh
```

その後、`dist/Lid Awake.app`または`/Applications/Lid Awake.app`を削除します。

## 言語

英語がprojectとfallbackの正本です。アプリはmacOSの言語設定に従い、英語と日本語の完全なUI resourceを含みます。

## License

[MIT License](LICENSE)
