# Lid Awake

MacBookを電源接続中に限り、蓋を閉じても起動状態に保つ個人利用向けmacOSアプリです。
iPhone版ChatGPTのRemoteから、Mac上のChatGPT/Codexへ接続する用途を想定しています。

## 状態

- 緑の「通常モード」: macOS標準のスリープ動作です。
- 赤の「常時起動中」: 蓋を閉じてもMacが動作を続けます。
- 黄の「安全停止」: AC切断または重大な熱状態を検出し、通常モードへ戻っています。

色だけに依存せず、状態名・説明・アイコンを併記します。

## 安全契約

- 常時起動はAC接続中だけ許可します。
- GUIアプリは10秒ごとにleaseを更新します。
- helperはleaseが30秒以上更新されない、owner processが終了した、ACが外れた、または
  macOSのthermal stateが`serious`以上になった場合、`pmset -a disablesleep 0`を実行します。
- helper起動時、アプリ終了時、アンインストール時は通常モードへ戻します。
- 再起動後に常時起動を自動復元しません。
- 画面ロックや認証を解除・迂回しません。

## ビルド

```bash
./scripts/check.sh
open 'dist/Lid Awake.app'
```

初回に「常時起動を開始」を押すと、helper登録のためmacOSの管理者認証が1回表示されます。

## アンインストール

```bash
./scripts/uninstall-helper.sh
```

その後、`dist/Lid Awake.app`または`/Applications/Lid Awake.app`を削除します。

## 制約

- このアプリが保証するのはMacのスリープ阻止までです。Wi-Fi、インターネット、OpenAI、
  ChatGPT/Codexアプリの生存は別の可用性条件です。
- FileVault有効環境で再起動した場合、ローカルログイン前にRemoteを復旧できません。
- 鞄、布団、ソファなど放熱できない場所では使用しません。

## 設計上の参照

蓋閉じスリープの阻止方法とfail-safe設計は、MITライセンスの
[Adrafinil](https://github.com/kageroumado/adrafinil)を参照しています。
本リポジトリは別実装であり、AIエージェント連携や無期限の永続設定は持ちません。
