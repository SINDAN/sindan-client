# change to english locale
chcp 437 > $null

$params = @{}

function Read-Conf([string]$filename) {
    $lines = Get-Content $filename -ErrorAction Stop
    foreach ($line in $lines) {
        if ($line -match '^\s*$') { continue }
        if ($line -match '^\s*[#;]') { continue }
        $param = $line.Split('=', 2)
        if ($param.Count -eq 2) {
            $params[$param[0].Trim()] = $param[1].Trim().Trim('"')
        }
    }
}

function Get-Param {
    param(
        [string[]]$Names,
        [string]$Default = ''
    )
    foreach ($name in $Names) {
        if ($params.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace($params[$name])) {
            return $params[$name]
        }
    }
    return $Default
}

function Split-List([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }
    return @($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Get-NowUtc() {
    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
}

function Ensure-LogDir() {
    if (-not (Test-Path '.\log')) {
        New-Item -Path '.\log' -ItemType Directory | Out-Null
    }
}

$script:campaign_uuid = [guid]::NewGuid().ToString()
$script:version = '6.0.1'

function Write-Json(
    [string]$layer,
    [string]$group,
    [string]$type,
    [string]$result,
    [string]$target,
    [string]$detail,
    [int]$count
) {
    $json_data = @{}
    $json_data['layer'] = $layer
    $json_data['log_group'] = $group
    $json_data['log_type'] = $type
    $json_data['log_campaign_uuid'] = $script:campaign_uuid
    $json_data['result'] = $result
    $json_data['target'] = $target
    $json_data['detail'] = $detail
    $json_data['occurred_at'] = Get-NowUtc

    $epoch = [int][double]::Parse((Get-Date -UFormat %s))
    $path = ".\log\sindan_${layer}_${type}_${count}_${epoch}.json"
    $json_data | ConvertTo-Json -Depth 8 | Out-File -FilePath $path -Encoding utf8
}

function Write-CampaignJson(
    [string]$macAddr,
    [string]$osInfo,
    [string]$networkType,
    [string]$networkId,
    [string]$hostName
) {
    $json_data = @{}
    $json_data['log_campaign_uuid'] = $script:campaign_uuid
    $json_data['mac_addr'] = $macAddr
    $json_data['os'] = $osInfo
    $json_data['network_type'] = $networkType
    $json_data['ssid'] = $networkId
    $json_data['hostname'] = $hostName
    $json_data['version'] = $script:version
    $json_data['occurred_at'] = Get-NowUtc

    $epoch = [int][double]::Parse((Get-Date -UFormat %s))
    $path = ".\log\campaign_${epoch}.json"
    $json_data | ConvertTo-Json -Depth 8 | Out-File -FilePath $path -Encoding utf8
}

function Get-WlanValue([string]$key) {
    $line = netsh wlan show interfaces | Select-String -Pattern "^\s*$([regex]::Escape($key))\s*:\s*(.+)$" | Select-Object -First 1
    if ($null -eq $line) { return '' }
    return $line.Matches[0].Groups[1].Value.Trim()
}

function Get-CurrentSSID() {
    return Get-WlanValue 'SSID'
}

function Get-ClockSyncState() {
    try {
        $status = w32tm /query /status 2>$null
        if ($status -match 'Source:\s+(.+)$') {
            return 'synchronized=true'
        }
        return 'synchronized=false'
    }
    catch {
        return ''
    }
}

function Get-ClockSource() {
    try {
        $status = w32tm /query /status 2>$null
        $sourceLine = $status | Where-Object { $_ -match '^Source:\s+' } | Select-Object -First 1
        if ($sourceLine -match '^Source:\s+(.+)$') {
            return $Matches[1].Trim()
        }
    }
    catch {
    }
    return ''
}

function Invoke-PingCheck(
    [string]$layer,
    [string]$version,
    [string]$type,
    [string]$target,
    [int]$count
) {
    $group = "IPv$version"
    $result = $FAIL
    $raw = ''
    try {
        $ping = Test-Connection -TargetName $target -Count 10 -IPv$version -ErrorAction Stop
        $raw = ($ping | Out-String).Trim()
        $result = $SUCCESS
        Write-Json $layer $group "v${version}alive_${type}" $result $target $raw $count

        $times = @($ping | Select-Object -ExpandProperty ResponseTime)
        if ($times.Count -gt 0) {
            $min = ($times | Measure-Object -Minimum).Minimum
            $max = ($times | Measure-Object -Maximum).Maximum
            $ave = [Math]::Round((($times | Measure-Object -Average).Average), 3)
            $dev = 0
            if ($times.Count -gt 1) {
                $variance = ($times | ForEach-Object { [math]::Pow(($_ - $ave), 2) } | Measure-Object -Sum).Sum / $times.Count
                $dev = [Math]::Round([Math]::Sqrt($variance), 3)
            }
            Write-Json $layer $group "v${version}rtt_${type}_min" $INFO $target "$min" $count
            Write-Json $layer $group "v${version}rtt_${type}_ave" $INFO $target "$ave" $count
            Write-Json $layer $group "v${version}rtt_${type}_max" $INFO $target "$max" $count
            Write-Json $layer $group "v${version}rtt_${type}_dev" $INFO $target "$dev" $count
            Write-Json $layer $group "v${version}loss_${type}" $INFO $target '0' $count
        }
    }
    catch {
        $raw = $_.Exception.Message
        Write-Json $layer $group "v${version}alive_${type}" $result $target $raw $count
        Write-Json $layer $group "v${version}loss_${type}" $INFO $target '100' $count
    }
}

function Invoke-TraceCheck(
    [string]$layer,
    [string]$version,
    [string]$type,
    [string]$target,
    [int]$count
) {
    $group = "IPv$version"
    $traceRaw = ''
    $path = @()
    try {
        if ($version -eq '4') {
            $trace = tracert -4 -d -h 20 -w 2000 $target
        }
        else {
            $trace = tracert -6 -d -h 20 -w 2000 $target
        }
        $traceRaw = ($trace | Out-String).Trim()
        Write-Json $layer $group "v${version}path_detail_${type}" $INFO $target $traceRaw $count

        foreach ($line in $trace) {
            if ($line -match '^\s*\d+\s+.*?([0-9a-fA-F:\.]+)\s*$') {
                $hop = $Matches[1]
                if ($hop -ne '*' -and $hop -ne 'Request') {
                    $path += $hop
                }
            }
        }
        Write-Json $layer $group "v${version}path_${type}" $INFO $target ($path -join ',') $count
    }
    catch {
        Write-Json $layer $group "v${version}path_detail_${type}" $INFO $target $_.Exception.Message $count
    }
}

function Invoke-PmtudCheck(
    [string]$layer,
    [string]$version,
    [string]$type,
    [string]$target,
    [int]$ifmtu,
    [int]$count,
    [string]$srcAddr
) {
    $group = "IPv$version"
    if ($version -ne '4') {
        Write-Json $layer $group "v${version}pmtu_${type}" $INFO $target "unmeasurable,$srcAddr" $count
        return
    }

    $low = 576
    $high = [Math]::Max($ifmtu, 576)
    $best = 0
    while (($high - $low) -gt 1) {
        $mid = [int](($low + $high) / 2)
        $payload = $mid - 28
        if ($payload -lt 0) { break }
        $cmd = "ping -4 -n 1 -w 1000 -f -l $payload $target"
        $res = cmd /c $cmd 2>&1
        $ok = (($res | Out-String) -match 'TTL=' -or ($res | Out-String) -match 'Reply from')
        if ($ok) {
            $best = $mid
            $low = $mid
        }
        else {
            $high = $mid
        }
    }

    if ($best -gt 0) {
        Write-Json $layer $group "v${version}pmtu_${type}" $INFO $target "$best,$srcAddr" $count
    }
    else {
        Write-Json $layer $group "v${version}pmtu_${type}" $INFO $target "unmeasurable,$srcAddr" $count
    }
}

function Invoke-DnsLookupCheck(
    [string]$layer,
    [string]$version,
    [string]$recordType,
    [string]$dnsServer,
    [int]$count,
    [string[]]$fqdns
) {
    $group = "IPv$version"
    foreach ($fqdn in $fqdns) {
        $result = $FAIL
        $raw = ''
        $answer = ''
        $ttl = ''
        $rtt = ''
        try {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $query = Resolve-DnsName -Name $fqdn -Type $recordType -Server $dnsServer -DnsOnly -ErrorAction Stop
            $sw.Stop()
            $result = $SUCCESS
            $raw = ($query | Out-String).Trim()
            $answers = @($query | Where-Object { $_.Section -eq 'Answer' })
            if ($answers.Count -gt 0) {
                $ttl = "$($answers[0].TTL)"
                $answerValues = @()
                foreach ($a in $answers) {
                    if ($recordType -eq 'A' -and $a.IPAddress) { $answerValues += $a.IPAddress }
                    if ($recordType -eq 'AAAA' -and $a.IPAddress) { $answerValues += $a.IPAddress }
                }
                $answer = ($answerValues -join ',')
            }
            $rtt = "$($sw.ElapsedMilliseconds)"
        }
        catch {
            $raw = $_.Exception.Message
        }

        Write-Json $layer $group "v${version}dnsqry_${recordType}_${fqdn}" $result $dnsServer $raw $count
        if ($result -eq $SUCCESS) {
            Write-Json $layer $group "v${version}dnsans_${recordType}_${fqdn}" $INFO $dnsServer $answer $count
            Write-Json $layer $group "v${version}dnsttl_${recordType}_${fqdn}" $INFO $dnsServer $ttl $count
            Write-Json $layer $group "v${version}dnsrtt_${recordType}_${fqdn}" $INFO $dnsServer $rtt $count
        }
    }
}

function Check-Dns64([string]$dnsServer) {
    try {
        $ans = Resolve-DnsName -Name 'ipv4only.arpa' -Type AAAA -Server $dnsServer -DnsOnly -ErrorAction Stop
        if ($ans) { return 'yes' }
    }
    catch {
    }
    return 'no'
}

function Invoke-HttpCheck(
    [string]$layer,
    [string]$version,
    [string]$type,
    [string]$target,
    [int]$count,
    [string]$proxyUrl
) {
    $group = "IPv$version"
    $result = $FAIL
    $detail = ''
    try {
        $invokeParams = @{
            Uri = $target
            Method = 'Head'
            TimeoutSec = 10
            MaximumRedirection = 3
            ErrorAction = 'Stop'
        }
        if (-not [string]::IsNullOrWhiteSpace($proxyUrl)) {
            $invokeParams['Proxy'] = $proxyUrl
        }
        $resp = Invoke-WebRequest @invokeParams
        $result = $SUCCESS
        $detail = "$($resp.StatusCode)"
    }
    catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__) {
            $detail = "$($_.Exception.Response.StatusCode.value__)"
        }
        else {
            $detail = $_.Exception.Message
        }
    }
    Write-Json $layer $group "v${version}http_${type}" $result $target $detail $count
}

function Invoke-SshCheck(
    [string]$layer,
    [string]$version,
    [string]$type,
    [string]$targetSpec,
    [int]$count
) {
    $group = "IPv$version"
    $parts = $targetSpec.Split('_', 2)
    $target = $parts[0]
    $result = $FAIL
    $detail = ''

    $sshKeyscan = Get-Command ssh-keyscan -ErrorAction SilentlyContinue
    if ($sshKeyscan) {
        try {
            $typeArg = if ($parts.Count -gt 1) { $parts[1] } else { 'rsa' }
            $cmd = "ssh-keyscan -$version -T 5 -t $typeArg $target"
            $out = cmd /c $cmd 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($out | Out-String))) {
                $result = $SUCCESS
                $detail = ($out | Out-String).Trim()
            }
            else {
                $detail = 'ssh-keyscan failed'
            }
        }
        catch {
            $detail = $_.Exception.Message
        }
    }
    else {
        try {
            $tnc = Test-NetConnection -ComputerName $target -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($tnc) {
                $result = $SUCCESS
                $detail = 'port 22 reachable'
            }
            else {
                $detail = 'port 22 unreachable'
            }
        }
        catch {
            $detail = $_.Exception.Message
        }
    }

    Write-Json $layer $group "v${version}ssh_${type}" $result $target $detail $count
}

function Invoke-PortScanCheck(
    [string]$layer,
    [string]$version,
    [string]$type,
    [string]$target,
    [int]$port,
    [int]$count
) {
    $group = "IPv$version"
    $result = $FAIL
    $detail = ''
    try {
        $tnc = Test-NetConnection -ComputerName $target -Port $port -InformationLevel Detailed -WarningAction SilentlyContinue
        if ($tnc.TcpTestSucceeded) {
            $result = $SUCCESS
            $detail = 'open'
        }
        else {
            $detail = 'closed'
        }
    }
    catch {
        $detail = $_.Exception.Message
    }
    Write-Json $layer $group "v${version}portscan_${port}" $result $target $detail $count
}

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
Read-Conf '.\sindan.conf'
Ensure-LogDir

$PIDFILE = Get-Param -Names @('PIDFILE', 'LOCKFILE') -Default '.\sindan.isrunning'
$MAX_RETRY = [int](Get-Param -Names @('MAX_RETRY') -Default '5')
$IFTYPE = Get-Param -Names @('IFTYPE') -Default 'Wi-Fi'
$RECONNECT = Get-Param -Names @('RECONNECT') -Default 'no'
$MODE = Get-Param -Names @('MODE') -Default 'client'
$EXCL_IPv4 = Get-Param -Names @('EXCL_IPv4') -Default 'no'
$EXCL_IPv6 = Get-Param -Names @('EXCL_IPv6') -Default 'no'
$PROXY_URL = Get-Param -Names @('PROXY_URL') -Default ''

$PING4_SRVS = Split-List (Get-Param -Names @('PING4_SRVS', 'PING_SRVS'))
$PING6_SRVS = Split-List (Get-Param -Names @('PING6_SRVS'))
$FQDNS = Split-List (Get-Param -Names @('FQDNS'))
$PDNS4_SRVS = Split-List (Get-Param -Names @('PDNS4_SRVS', 'GPDNS4'))
$PDNS6_SRVS = Split-List (Get-Param -Names @('PDNS6_SRVS', 'GPDNS6'))
$WEB4_SRVS = Split-List (Get-Param -Names @('WEB4_SRVS', 'V4WEB_SRVS'))
$WEB6_SRVS = Split-List (Get-Param -Names @('WEB6_SRVS', 'V6WEB_SRVS'))
$SSH4_SRVS = Split-List (Get-Param -Names @('SSH4_SRVS'))
$SSH6_SRVS = Split-List (Get-Param -Names @('SSH6_SRVS'))
$PS4_SRVS = Split-List (Get-Param -Names @('PS4_SRVS'))
$PS6_SRVS = Split-List (Get-Param -Names @('PS6_SRVS'))
$PS_PORTS = Split-List (Get-Param -Names @('PS_PORTS'))

$FAIL = Get-Param -Names @('FAIL') -Default '0'
$SUCCESS = Get-Param -Names @('SUCCESS') -Default '1'
$INFO = Get-Param -Names @('INFO') -Default '10'

if (Test-Path $PIDFILE) {
    $oldPid = Get-Content $PIDFILE -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $PIDFILE -Force -ErrorAction SilentlyContinue
}
$PID | Out-File $PIDFILE -Encoding ascii -Force

try {
    Write-Host 'Phase 0: Hardware Layer checking...'
    $layer = 'hardware'

    $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
    $hostname = [System.Net.Dns]::GetHostName()
    $sys = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

    $hwInfo = "$($sys.Manufacturer),$($sys.Model)"
    if ($hwInfo) { Write-Json $layer 'common' 'hw_info' $INFO 'self' $hwInfo 0 }

    if ($cpu.MaxClockSpeed) { Write-Json $layer 'common' 'cpu_freq' $INFO 'self' "$($cpu.MaxClockSpeed * 1000000)" 0 }

    $clockState = Get-ClockSyncState
    if ($clockState) { Write-Json $layer 'common' 'clock_state' $INFO 'self' $clockState 0 }

    $clockSrc = Get-ClockSource
    if ($clockSrc) { Write-Json $layer 'common' 'clock_src' $INFO 'self' $clockSrc 0 }

    Write-Host ' done.'

    Write-Host 'Phase 1: Datalink Layer checking...'
    $layer = 'datalink'

    $ifname = $IFTYPE
    if ($RECONNECT -eq 'yes') {
        Disable-NetAdapter -Name $ifname -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Enable-NetAdapter -Name $ifname -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }

    Write-Json $layer 'common' 'iftype' $INFO 'self' $IFTYPE 0

    $ifstatus = 'inactive'
    $resultPhase1 = $FAIL
    for ($i = 0; $i -lt $MAX_RETRY; $i++) {
        $netadapter = Get-NetAdapter -Name $ifname -ErrorAction SilentlyContinue
        if ($netadapter -and $netadapter.Status -eq 'Up') {
            $ifstatus = 'active'
            $resultPhase1 = $SUCCESS
            break
        }
        Start-Sleep -Seconds 5
    }
    Write-Json $layer $IFTYPE 'ifstatus' $resultPhase1 'self' $ifstatus 0

    if ($netadapter) {
        if ($netadapter.MacAddress) {
            $macAddr = ($netadapter.MacAddress -replace '-', ':').ToLower()
            Write-Json $layer $IFTYPE 'mac_addr' $INFO 'self' $macAddr 0
        }
        if ($netadapter.MtuSize) {
            $ifmtu = [int]$netadapter.MtuSize
            Write-Json $layer $IFTYPE 'ifmtu' $INFO 'self' "$ifmtu" 0
        }
    }

    $wlanSsid = 'none'
    if ($IFTYPE -eq 'Wi-Fi') {
        $wlanSsid = Get-CurrentSSID
        if ($wlanSsid) { Write-Json $layer $IFTYPE 'wlan_ssid' $INFO 'self' $wlanSsid 0 }

        $bssid = Get-WlanValue 'BSSID'
        if ($bssid) { Write-Json $layer $IFTYPE 'wlan_bssid' $INFO 'self' $bssid 0 }

        $radioType = Get-WlanValue 'Radio type'
        if ($radioType) { Write-Json $layer $IFTYPE 'wlan_mode' $INFO 'self' $radioType 0 }

        $channel = Get-WlanValue 'Channel'
        if ($channel) { Write-Json $layer $IFTYPE 'wlan_channel' $INFO 'self' $channel 0 }

        $txRate = Get-WlanValue 'Transmit rate (Mbps)'
        if ($txRate) { Write-Json $layer $IFTYPE 'wlan_rate' $INFO 'self' $txRate 0 }

        $signal = Get-WlanValue 'Signal'
        if ($signal) { Write-Json $layer $IFTYPE 'wlan_quality' $INFO 'self' ($signal -replace '%', '') 0 }
    }

    Write-Host ' done.'

    Write-Host 'Phase 2: Interface Layer checking...'
    $layer = 'interface'

    $v4addr = ''
    $v6addrs = @()
    $v4routers = @()
    $v6routers = @()
    $v4nameservers = @()
    $v6nameservers = @()

    if ($EXCL_IPv4 -ne 'yes') {
        $ip4if = Get-NetIPInterface -InterfaceAlias $ifname -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ip4if) {
            $v4ifconf = if ($ip4if.Dhcp -eq 'Enabled') { 'dhcp' } else { 'manual' }
            Write-Json $layer 'IPv4' 'v4ifconf' $INFO 'self' $v4ifconf 0
        }

        $ipconf = Get-NetIPConfiguration -InterfaceAlias $ifname -ErrorAction SilentlyContinue
        if ($ipconf -and $ipconf.IPv4Address) {
            $v4addr = $ipconf.IPv4Address.IPAddress
            Write-Json $layer 'IPv4' 'v4autoconf' $SUCCESS 'self' $v4addr 0
            Write-Json $layer 'IPv4' 'v4addr' $INFO 'self' $v4addr 0
            $mask = [IPAddress](([uint32]0xffffffff) -shl (32 - $ipconf.IPv4Address.PrefixLength) -shr 0)
            Write-Json $layer 'IPv4' 'netmask' $INFO 'self' $mask.IPAddressToString 0
        }
        else {
            Write-Json $layer 'IPv4' 'v4autoconf' $FAIL 'self' 'no IPv4 address' 0
        }

        if ($ipconf -and $ipconf.IPv4DefaultGateway) {
            $v4routers = @($ipconf.IPv4DefaultGateway.NextHop | Where-Object { $_ })
            Write-Json $layer 'IPv4' 'v4routers' $INFO 'self' ($v4routers -join ',') 0
        }

        $dns4 = Get-DnsClientServerAddress -InterfaceAlias $ifname -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($dns4) {
            $v4nameservers = @($dns4.ServerAddresses | Where-Object { $_ })
            if ($v4nameservers.Count -gt 0) {
                Write-Json $layer 'IPv4' 'v4nameservers' $INFO 'self' ($v4nameservers -join ',') 0
            }
        }
    }

    if ($EXCL_IPv6 -ne 'yes') {
        $ip6if = Get-NetIPInterface -InterfaceAlias $ifname -AddressFamily IPv6 -ErrorAction SilentlyContinue
        if ($ip6if) {
            $v6ifconf = if ($ip6if.RouterDiscovery -eq 'Enabled') { 'automatic' } else { 'manual' }
            Write-Json $layer 'IPv6' 'v6ifconf' $INFO 'self' $v6ifconf 0
        }

        $ip6all = Get-NetIPAddress -InterfaceAlias $ifname -AddressFamily IPv6 -ErrorAction SilentlyContinue
        $ll = $ip6all | Where-Object { $_.IPAddress -like 'fe80*' } | Select-Object -First 1
        if ($ll) {
            Write-Json $layer 'IPv6' 'v6lladdr' $INFO 'self' $ll.IPAddress 0
        }

        $v6global = @($ip6all | Where-Object { $_.IPAddress -notlike 'fe80*' -and $_.IPAddress -ne '::1' } | Select-Object -ExpandProperty IPAddress)
        if ($v6global.Count -gt 0) {
            $v6addrs = $v6global
            Write-Json $layer 'IPv6' 'v6addrs' $INFO 'self' ($v6addrs -join ',') 0
            Write-Json $layer 'IPv6' 'v6autoconf' $SUCCESS 'self' 'ok' 0
        }

        $ipconf6 = Get-NetIPConfiguration -InterfaceAlias $ifname -ErrorAction SilentlyContinue
        if ($ipconf6 -and $ipconf6.IPv6DefaultGateway) {
            $v6routers = @($ipconf6.IPv6DefaultGateway.NextHop | Where-Object { $_ })
            Write-Json $layer 'IPv6' 'v6routers' $INFO 'self' ($v6routers -join ',') 0
        }

        $dns6 = Get-DnsClientServerAddress -InterfaceAlias $ifname -AddressFamily IPv6 -ErrorAction SilentlyContinue
        if ($dns6) {
            $v6nameservers = @($dns6.ServerAddresses | Where-Object { $_ })
            if ($v6nameservers.Count -gt 0) {
                Write-Json $layer 'IPv6' 'v6nameservers' $INFO 'self' ($v6nameservers -join ',') 0
            }
        }
    }

    Write-Host ' done.'

    Write-Host 'Phase 3: Localnet Layer checking...'
    $layer = 'localnet'

    $c = 0
    foreach ($target in $v4routers) { Invoke-PingCheck $layer '4' 'router' $target $c; $c++ }
    $c = 0
    foreach ($target in $v4nameservers) { Invoke-PingCheck $layer '4' 'namesrv' $target $c; $c++ }
    $c = 0
    foreach ($target in $v6routers) { Invoke-PingCheck $layer '6' 'router' $target $c; $c++ }
    $c = 0
    foreach ($target in $v6nameservers) { Invoke-PingCheck $layer '6' 'namesrv' $target $c; $c++ }

    Write-Host ' done.'

    Write-Host 'Phase 4: Globalnet Layer checking...'
    $layer = 'globalnet'

    if ($EXCL_IPv4 -ne 'yes' -and -not [string]::IsNullOrWhiteSpace($v4addr)) {
        $c = 0
        foreach ($target in $PING4_SRVS) {
            Invoke-PingCheck $layer '4' 'srv' $target $c
            Invoke-TraceCheck $layer '4' 'srv' $target $c
            if ($netadapter -and $netadapter.MtuSize) {
                Invoke-PmtudCheck $layer '4' 'srv' $target ([int]$netadapter.MtuSize) $c $v4addr
            }
            $c++
        }
    }

    if ($EXCL_IPv6 -ne 'yes' -and $v6addrs.Count -gt 0) {
        $c = 0
        foreach ($target in $PING6_SRVS) {
            Invoke-PingCheck $layer '6' 'srv' $target $c
            Invoke-TraceCheck $layer '6' 'srv' $target $c
            foreach ($src in $v6addrs) {
                if ($netadapter -and $netadapter.MtuSize) {
                    Invoke-PmtudCheck $layer '6' 'srv' $target ([int]$netadapter.MtuSize) $c $src
                }
            }
            $c++
        }
    }

    Write-Host ' done.'

    Write-Host 'Phase 5: DNS Layer checking...'
    $layer = 'dns'
    Clear-DnsClientCache -ErrorAction SilentlyContinue

    if ($FQDNS.Count -gt 0) {
        $c = 0
        foreach ($dns in $v4nameservers) {
            if ($MODE -eq 'probe') { Invoke-PingCheck $layer '4' 'namesrv' $dns $c }
            Invoke-DnsLookupCheck $layer '4' 'A' $dns $c $FQDNS
            Invoke-DnsLookupCheck $layer '4' 'AAAA' $dns $c $FQDNS
            $c++
        }

        $c = 0
        foreach ($dns in $PDNS4_SRVS) {
            if ($MODE -eq 'probe') {
                Invoke-PingCheck $layer '4' 'namesrv' $dns $c
                Invoke-TraceCheck $layer '4' 'namesrv' $dns $c
            }
            Invoke-DnsLookupCheck $layer '4' 'A' $dns $c $FQDNS
            Invoke-DnsLookupCheck $layer '4' 'AAAA' $dns $c $FQDNS
            $c++
        }

        $existDns64 = 'no'
        $c = 0
        foreach ($dns in $v6nameservers) {
            if ($MODE -eq 'probe') { Invoke-PingCheck $layer '6' 'namesrv' $dns $c }
            Invoke-DnsLookupCheck $layer '6' 'A' $dns $c $FQDNS
            Invoke-DnsLookupCheck $layer '6' 'AAAA' $dns $c $FQDNS
            if ($existDns64 -ne 'yes') {
                $existDns64 = Check-Dns64 $dns
            }
            $c++
        }

        $c = 0
        foreach ($dns in $PDNS6_SRVS) {
            if ($MODE -eq 'probe') {
                Invoke-PingCheck $layer '6' 'namesrv' $dns $c
                Invoke-TraceCheck $layer '6' 'namesrv' $dns $c
            }
            Invoke-DnsLookupCheck $layer '6' 'A' $dns $c $FQDNS
            Invoke-DnsLookupCheck $layer '6' 'AAAA' $dns $c $FQDNS
            $c++
        }
    }

    Write-Host ' done.'

    Write-Host 'Phase 6: Application Layer checking...'
    $layer = 'app'

    $c = 0
    foreach ($target in $WEB4_SRVS) {
        if ($MODE -eq 'probe') {
            Invoke-PingCheck $layer '4' 'websrv' $target $c
            Invoke-TraceCheck $layer '4' 'websrv' $target $c
        }
        Invoke-HttpCheck $layer '4' 'websrv' $target $c $PROXY_URL
        $c++
    }

    $c = 0
    foreach ($target in $WEB6_SRVS) {
        if ($MODE -eq 'probe') {
            Invoke-PingCheck $layer '6' 'websrv' $target $c
            Invoke-TraceCheck $layer '6' 'websrv' $target $c
        }
        Invoke-HttpCheck $layer '6' 'websrv' $target $c $PROXY_URL
        $c++
    }

    $c = 0
    foreach ($target in $SSH4_SRVS) {
        if ($MODE -eq 'probe') {
            $fqdn = $target.Split('_', 2)[0]
            Invoke-PingCheck $layer '4' 'sshsrv' $fqdn $c
            Invoke-TraceCheck $layer '4' 'sshsrv' $fqdn $c
        }
        Invoke-SshCheck $layer '4' 'sshsrv' $target $c
        $c++
    }

    $c = 0
    foreach ($target in $SSH6_SRVS) {
        if ($MODE -eq 'probe') {
            $fqdn = $target.Split('_', 2)[0]
            Invoke-PingCheck $layer '6' 'sshsrv' $fqdn $c
            Invoke-TraceCheck $layer '6' 'sshsrv' $fqdn $c
        }
        Invoke-SshCheck $layer '6' 'sshsrv' $target $c
        $c++
    }

    $c = 0
    foreach ($target in $PS4_SRVS) {
        foreach ($portText in $PS_PORTS) {
            $port = [int]$portText
            Invoke-PortScanCheck $layer '4' 'pssrv' $target $port $c
        }
        $c++
    }

    $c = 0
    foreach ($target in $PS6_SRVS) {
        foreach ($portText in $PS_PORTS) {
            $port = [int]$portText
            Invoke-PortScanCheck $layer '6' 'pssrv' $target $port $c
        }
        $c++
    }

    Write-Host ' done.'

    Write-Host 'Phase 7: Create campaign log...'

    $macCampaign = if ($netadapter -and $netadapter.MacAddress) { ($netadapter.MacAddress -replace '-', ':').ToLower() } else { '' }
    $networkId = if ($IFTYPE -eq 'Wi-Fi') { $wlanSsid } else { 'none' }
    Write-CampaignJson $macCampaign $osInfo $IFTYPE $networkId $hostname

    Write-Host ' done.'
}
finally {
    Remove-Item $PIDFILE -Force -ErrorAction SilentlyContinue
}

exit 0
