# セキュリティポリシー

## 対象バージョン

`main`の最新版だけをサポートします。署名・notarize済みの公式バイナリは現在配布していません。
第三者が再配布したバイナリはサポート対象外です。

## 脆弱性の報告

公開前のprivate review中はrepository ownerへ非公開で連絡してください。公開後は
[GitHub Security Advisory](https://github.com/ShimpeiTakeda/lid-awake/security/advisories/new)から報告してください。
Issue、Discussion、SNSへ脆弱性の再現手順や未修正の詳細を書かないでください。

報告には、影響するcommit、macOSとMacの機種、再現手順、期待結果、実際の結果、影響範囲を含めてください。
token、cookie、個人情報、ChatGPTの会話内容は添付しないでください。

## 権限境界

本アプリは`pmset -a disablesleep`を変更するため、rootのLaunchDaemonを導入します。helperが実行する
外部commandは固定された`/usr/bin/pmset`だけです。install時は管理者認証前に取得したSHA-256と、root所有の
staging領域へコピーした成果物を照合してからsystem pathを更新します。

既知の残余リスクと配布条件は[脅威モデル](docs/THREAT_MODEL.md)および
[release checklist](docs/RELEASE_CHECKLIST.md)を参照してください。
