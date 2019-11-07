
# sindan-client

## About SINDAN Project
Please visit website [sindan-net.com](https://www.sindan-net.com) for more details. (Japanese edition only)

> In order to detect network failure, SINDAN project evaluates the network status based on user-side observations, and aims to establish a method that enables network operators to troubleshoot quickly.

## Installation
このスクリプトはLinux版、macOS版およびWindows版があります。
macOS版はmacOS標準のコマンド等を利用するため、別途アプリケーションの導入を必要としません。
Linux版は以下のパケージを必要とします。
- dnsutils, uuid-runtime, ndisc6

This script 

## Usage

## Configuration

sindan.shと同じディレクトリに配置することを想定している
設定パラメータ：
LOCKFILE sindan.shの動作チェックファイルの指定
	　LOCKFILE_SENDLOG	sendlog.shの動作チェックファイルの指定
	　FAIL	, SUCCESS, INFO	判定パラメータ値の設定
MODE
	　RECONNECT		yesの場合、L2の切断/接続を実施
	　VERBOSE			yesの場合、sindan.sh実施時に詳細情報を出力
	　MAX_RETRY		datalink, interfaceでのチェックを繰り返す最大値
					デフォルトは10
	　IFTYPE			計測インタフェースのタイプを指定
					Wi-Fiとそれ以外で区別
	　DEVNAME			計測インタフェースの名前を指定（例：ra0）
	　SSID, SSID_KEY		（現バージョンでは利用しない）
	　PING_SRVS		IPv4到達性確認用の外部サーバ（,区切り）
	　PING6_SRVS		IPv6到達性確認用の外部サーバ（,区切り）
	　FQDNS			名前解決に用いるFQDNの指定（,区切り）
	　GPDNS4			名前解決に用いるIPv4外部DNSサーバ（,区切り）
	　GPDNS6			名前解決に用いるIPv6外部DNSサーバ（,区切り）
	　V4WEB_SRVS		HTTP通信確認に用いるIPv4ウェブサーバ（,区切り）
	　V6WEB_SRVS		HTTP通信確認に用いるIPv6ウェブサーバ（,区切り）
	　URL_CAMPAIGN		計測メタデータ送信先URLの指定
					http://<server_name>:<port>/sindan.log_campaign
	　URL_SINDAN		計測データ送信先URLの指定
					http://<server_name>:<port>/sindan.log
	＜NFDF計測用パラメータ＞
	　COMMUNICATION_DEVICE	SINDANでの計測対象インタフェースの指定
	　MONITOR_DEVIDE		NFDF計測を実施するインタフェースの指定
	　MONITOR_REFRESH_TIME	NFDF計測での計測ファイル更新頻度（秒）


## Authors
- **Yoshiaki KITAGUCHI** - *Maintein macOS/Linux version* [@kitaguch](https://github.com/kitaguch)
- **Tomohiro ISHIHARA** - *Maintein Windows version* - [@shored](https://github.com/shored)

See also the list of [contributors](https://github.com/SINDAN/sindan-client/graphs/contributors) who participated in this project.

## License
This project is licensed under the BSD 3-Clause "New" or "Revised" License - see the [LICENSE](LICENSE) file for details.
