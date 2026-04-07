# SINDAN client Windows

Windows 版 SINDAN クライアントの実行方法と制限事項をまとめたドキュメントです。

## 注意

- Windows 版は Linux/macOS 版に比べて機能が限定されています。
- 可能であれば Linux/macOS 版の利用を推奨します。

## 使い方

1. PowerShell を開き、`windows` ディレクトリに移動します。
2. `sindan.conf` を環境に合わせて編集します。
3. 診断を実行します。
4. 生成された JSON ログを送信します。

実行例:

```powershell
cd .\windows
.\sindan.ps1
.\sendlog.ps1
```

ログ保存先:

- `windows/log/*.json` に診断ログが出力されます。
- `DEBUG_LOG=yes` の場合、`windows/log/sindan_debug_*.log` にデバッグログが出力されます。

## 設定ファイル

設定ファイルは `windows/sindan.conf` です。主な項目:

- `IFTYPE` : 対象インターフェース名。通常は `Wi-Fi`。
- `RECONNECT` : `yes` の場合に I/F の Up/Down を実施。
- `PING_SRVS`, `PING6_SRVS` : 到達性確認先。
- `FQDNS`, `GPDNS4`, `GPDNS6` : DNS 確認先。
- `V4WEB_SRVS`, `V6WEB_SRVS` : HTTP 確認先。
- `CAMPAIGN_ENDPOINT`, `SENDLOG_ENDPOINT` : ログ送信先。
- `DO_SPEEDTEST` : `yes` で speedtest を実行。
- `SPEEDTEST_CMD` : speedtest コマンド名またはパス。
- `ST_SRVS` : speedtest サーバー ID 一覧（カンマ区切り、空なら自動選択）。

## speedtest の導入

Windows では `winget` を使うのが最も簡単です。

1. speedtest CLI をインストール:

```powershell
winget install --id Ookla.Speedtest.CLI --exact --source winget
```

2. 動作確認:

```powershell
speedtest --version
```

3. `sindan.conf` 側の設定例:

```conf
DO_SPEEDTEST=yes
SPEEDTEST_CMD=speedtest
ST_SRVS=
```

補足:

- `winget` 初回実行時に利用規約同意を求められる場合があります。
- 企業端末などで `winget` が使えない場合は、管理ポリシーに従って代替手段を利用してください。

## 未実装・制限事項

現時点の Windows 版で、Linux/macOS 版に比べて不足している主な項目です。

- PID ファイルベースの多重起動制御と前回プロセス停止処理。
- `MAX_RETRY` を使った複数回リトライ判定。
- Wi-Fi 詳細メトリクスの一部: `wlan_bssid`, `wlan_mcs`, `wlan_nss`, `wlan_mode`, `wlan_band`, `wlan_chband`, `wlan_quality`, `wlan_environment`。
- WWAN 系メトリクス群（APN/RAT/RSRP/RSRQ など）。
- IPv6 RA 詳細解析と `v6autoconf` 検証。
- IPv6 PMTUD（現在は未実装扱い）。
- DNS フェーズでの probe 相当（nameserver への ping/traceroute、DNS64 判定）。
- アプリ層の SSH 到達確認・ポートスキャン。
- `MODE=probe/client` 切替動作。
- 実行終了時の campaign ログファイル生成処理。
