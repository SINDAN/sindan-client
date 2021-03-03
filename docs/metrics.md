# SINDAN Measurement Metrics
## Layer

| Layer Name ||
|---|---|
| ハードウェア層(hardware) | ネットワーク計測を実施するクライアント端末の状態を把握するために、ハードウェア情報などを収集する。 |
| インタフェース設定層(interface) | OSI参照モデルのLayer3におけるIPアドレス設定を確認する層である。IPv4の場合はDHCPによる自動アドレス設定の確認、IPv6の場合はRAによるSLAACもしくは、DHCPv6による自動アドレス設定の確認を行う。 |
| データリンク層(datalink) |　OSI参照モデルにおけるLayer 2と同じ層で、隣接機器との接続性を確認するための計測層である。ネットワークインタフェースのdown/upにより、リンクアップできるまでを確認する。無線ネットワークにおいては、Assosiationが確立されるまでの計測となる。合わせて、リンクアップにおける接続パラメータの収集を行う。　|
| ローカルネットワーク層(localnet) | 同一セグメント（ローカルネットワーク）におけるIPの到達性を確認する層である。ローカルネットワークにおけるサービス発見としてmDNS（Bonjour, Avahi）やLLMNR（Windows）を用いたサービス確認がこの層になるが、現段階ではデフォルトルートとネームサーバへの到達性確認のみ実施する。 |
| グローバルネットワーク層(globalnet) | 組織外の外部サーバへのIP的な到達性を確認する層である。到達性の確認（pingによるRTTとtracerouteによるパス計測）と合わせて、パスMTUを計測する。 |
| 名前解決層(dns) | アプリケーションを利用する際に必須となる機能として、ドメイン名からIPアドレスを取得する名前解決があり、この名前解決の確認を行う層がこの層である。名前解決はデュアルスタックになるとIPv4とIPv6双方での確認が必要であり、また、OSが提供するresolver API毎に挙動が異なる。そのため、以下の調査をDHCP/DHCPv6で得られたネームサーバとGoogleパブリックDNSサーバに対して実施する。 |
| アプリケーション層(app) | OSI参照モデルにおけるLayer5以上の層に相当する機能を確認する層で、現在はアプリケーション層の評価を行う。この層では、組織外の外部サーバに対してアプリケーション層の通信が可能か確認する。 |

## Metrics

| Layer | Metric ||
|---|---|---|
| ハードウェア層(hardware) | hw_info | |
| ハードウェア層(hardware) | cpu_freq | |
| ハードウェア層(hardware) | cpu_volt | |
| ハードウェア層(hardware) | cpu_temp | |
| ハードウェア層(hardware) | clock_state | |
| ハードウェア層(hardware) | clock_src | |
| ハードウェア層(hardware) | os | at campaign|
| データリンク層(datalink) | mtu | |
| データリンク層(datalink) | mac_addr | |
| データリンク層(datalink) | media | 有線ネットワークのみ |
| データリンク層(datalink) | bssid | 無線ネットワークのみ |
| データリンク層(datalink) | ssid | 無線ネットワークのみ |
| データリンク層(datalink) | rssi | 無線ネットワークのみ |
| データリンク層(datalink) | noise | 無線ネットワークのみ |
| データリンク層(datalink) | rate | 無線ネットワークのみ |
| データリンク層(datalink) | channel|  無線ネットワークのみ |
| インタフェース設定層(interface) | v4addr | IPv4 |
| インタフェース設定層(interface) | netmask | IPv4 |
| インタフェース設定層(interface) | v4routers | IPv4 |
| インタフェース設定層(interface) | v4namesrvs | IPv4 |
| インタフェース設定層(interface) | v4ntpsrvs | IPv4 |
| インタフェース設定層(interface) | v6lladdr | IPv6 |
| インタフェース設定層(interface) | v6addrs | IPv6 |
| インタフェース設定層(interface) | preflen | IPv6 |
| インタフェース設定層(interface) | v6routers | IPv6 |
| インタフェース設定層(interface) | v6namesrvs | IPv6 |
| インタフェース設定層(interface) | v6ntpsrvs | IPv6 |
| インタフェース設定層(interface) | ra_prefix | IPv6 |
| インタフェース設定層(interface) | ra_prefix_flags | IPv6 |
| インタフェース設定層(interface) | ra_flags | IPv6 |
| ローカルネットワーク層(localnet) | v4rtt_router | |
| ローカルネットワーク層(localnet) | v4rtt_namesrv | |
| ローカルネットワーク層(localnet) | v6rtt_router | |
| ローカルネットワーク層(localnet) | v6rtt_namesrv | |
| グローバルネットワーク層(globalnet) | v4alive_srv | ping |
| グローバルネットワーク層(globalnet) | v6alive_srv | ping |
| グローバルネットワーク層(globalnet) | v4rtt_srv | |
| グローバルネットワーク層(globalnet) | v6rtt_srv | |
| グローバルネットワーク層(globalnet) | v4path_srv | |
| グローバルネットワーク層(globalnet) | v6path_srv | |
| グローバルネットワーク層(globalnet) | v4pmtu_srv | |
| グローバルネットワーク層(globalnet) | v6pmtu_srv | |
| グローバルネットワーク層(globalnet) | v4loss_srv | |
| グローバルネットワーク層(globalnet) | v6loss_srv | |
| 名前解決層(dns) | v4dnsqry_#{type}_#{query} | type: A / AAAA, query: dual.sindan-net.com (dualstack) / v4only.sindan-net.com (v4only) / v6only.sindan-net.com (v6only) |
| 名前解決層(dns) | v6dnsqry_#{type}_#{query} | type: A / AAAA, query: dual.sindan-net.com (dualstack) / v4only.sindan-net.com (v4only) / v6only.sindan-net.com (v6only) |
| アプリケーション層(app) | v4http_websrv | HTTP/HTTPS通信の確認 |
| アプリケーション層(app) | v6http_websrv | HTTP/HTTPS通信の確認 |
| アプリケーション層(app) | v4http_throughput_srv | (TBD) |
| アプリケーション層(app) | v6http_throughput_srv | (TBD) |
| アプリケーション層(app) | v4portscan_#{port} | ポート開放状況の確認. port: 22(ssh) / 80(http) / 443(https) |
| アプリケーション層(app) | v6portscan_#{port} | ポート開放状況の確認. port: 22(ssh) / 80(http) / 443(https) |
| アプリケーション層(app) | v4ssh_sshsrv | SSHサーバ通信、サーバ鍵の確認 |
| アプリケーション層(app) | v6ssh_sshsrv | SSHサーバ通信、サーバ鍵の確認 |
| アプリケーション層(app) | speedindex | node.jsを利用したスピードインデックス、スピードテスト計測 |
| アプリケーション層(app) | speedtest | iNonius |
| アプリケーション層(app) | (TBD) | Happy Eyeballによる閲覧確認（予定） |
| アプリケーション層(app) | (TBD) | DFビットが有効なウェブサーバへの通信確認（IPv4）（予定） |
| アプリケーション層(app) | (TBD) | ISPにおける通信の最適化処理の影響確認（予定） |
