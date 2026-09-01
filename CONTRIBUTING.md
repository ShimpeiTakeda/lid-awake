# Contributing

## 変更方針

Lid Awakeは「AC接続中だけ」「アプリの生存期間だけ」「1つのボタンで開始・終了」という小さい挙動契約を
維持します。機能追加よりfail-safe、権限境界、復旧可能性を優先します。

Issueを先に作成し、変更目的、利用者への影響、権限や安全条件への影響を説明してください。秘密情報、端末名、
ユーザー名、ChatGPTの会話内容をIssueやtest fixtureへ含めないでください。

## 開発環境

- macOS 14以降
- Swift 6
- Xcode Command Line Tools

```bash
git clone https://github.com/ShimpeiTakeda/lid-awake.git
cd lid-awake
./scripts/check.sh
```

## Pull Request gate

- public APIや利用者向け挙動を変える場合、Issueで合意した理由をPRへ記載します。
- failure modeを追加・変更した場合、成功系だけでなく安全側への復帰testを追加します。
- root helper、install command、`pmset`、lease、file permissionの変更は
  [脅威モデル](docs/THREAT_MODEL.md)も更新します。
- `./scripts/check.sh`をpassさせます。
- 実機確認を行った場合だけ、そのcommitと条件をPRへ記載します。過去の実測を新しいcommitの証拠にしません。
- 生成物、署名情報、credential、local status/leaseをcommitしません。

## Commit

1つのcommitへ無関係な変更を混ぜません。署名・notarize・release作成はmaintainerだけが行います。
