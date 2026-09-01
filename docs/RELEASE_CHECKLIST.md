# Release checklist

## Source repository公開gate

- [x] MIT Licenseを明示する
- [x] READMEへ目的、権限、安全条件、制約、build、uninstallを記載する
- [x] SECURITY、CONTRIBUTING、Code of Conduct、Changelogを用意する
- [x] 脅威モデルと残余リスクを公開する
- [x] CIを最小権限・固定commitのactionで実行する
- [x] safety policyの全分岐、境界値、file permission、timeout、installer commandをtestする
- [x] build後のbundle ID、plist、code signature、格納物を監査する
- [x] tracked fileのsecret pattern、local artifact、大容量fileを監査する
- [ ] ownerがprivate repositoryのsource diffをreviewする
- [ ] 公開直前のGitHub設定と表示をreviewする

上の未完了2項目はowner reviewのため意図的に残しています。owner review前にpublicへ変更しません。

## Binary release gate

- [ ] Apple Developer Programの配布用identityを用意する
- [ ] Developer ID Applicationでappとhelperを署名する
- [ ] hardened runtimeと必要最小限のentitlementを確定する
- [ ] Apple notarizationとticket staplingを行う
- [ ] cleanなsupported macOS環境でinstall、更新、uninstallを検証する
- [ ] AC切断、app kill、helper restart、thermal safety stopを配布buildで実測する
- [ ] checksumと署名検証手順をrelease noteへ記載する

全項目が完了するまでGitHub Releaseへ実行バイナリを添付しません。ad-hoc署名buildはlocal development専用です。
