# Test strategy

## 原則

testは「開始できる」だけでなく「条件を失ったら確実に解除へ向かう」を主対象にします。rootの実system設定を
CIで変更しません。純粋policy、file system、subprocess、build artifact、実機journeyを層別化します。

## 自動test

| Layer | 対象 | Hard fail |
|---|---|---|
| Policy | lease有無、schema、enabled、時刻境界、PID、path、AC、thermal、優先順位 | 不安全な条件で`.active`になる |
| Transition | 起動時不明状態、成功state、適用失敗後の再試行 | 失敗後に解除遷移を省略する |
| Parser | `pmset -g`の0/1、欠落、不正値、類似key | 実状態を誤認する |
| File | JSON round trip、0700/0600、atomic replace、malformed JSON | 権限緩和、一時file残留、壊れた状態の受理 |
| Process | stdout/stderr/exit、pipe容量超過、timeout、invalid timeout | helper threadが無期限停止する |
| Installer | path quote、digest validation、root staging順序、shell syntax | 検証前にsystem pathを変更する |
| Artifact | bundle ID、minimum OS、helper plist、code signature、格納file | 想定外file、識別子不一致、署名破損 |
| Source | format、shell syntax、secret pattern、local artifact、1 MiB超file | 非公開情報や生成物を公開対象へ含める |

canonical commandは次です。

```bash
./scripts/check.sh
```

## 実機test

root helperと実際の蓋閉じ挙動は[実機検証手順](VERIFICATION.md)で確認します。実測はcommitに紐づけ、別commitへ
流用しません。特に次はCIの代替になりません。

- 管理者認証を含むfresh installとupdate
- AC切断、app kill、helper restart
- 蓋を閉じた状態の別networkからのChatGPT Remote
- signed/notarized distribution buildのGatekeeper検証

## Coverageの解釈

line coverageの数値だけを品質gateにしません。root権限境界とfailure modeは、分岐がtestまたは実機手順のどちらに
属するかを明示します。未検証の実機項目をunit test成功でcoveredと呼びません。
