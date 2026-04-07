# change to english locale
chcp 437

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$debugEnabled = $true
$debugLogDir = Join-Path $scriptDir "log"
$debugLogPath = $null

trap {
    Write-Host "fatal error: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace
    }
    if ($debugEnabled) {
        try {
            Stop-Transcript | Out-Null
        } catch {
        }
    }
    exit 1
}

$params = @{  }
$body = @{ }
$campaignEndpoint = $null
$doSpeedtest = $false
$speedtestCmd = "speedtest"
$speedtestServerIds = @()

function read_conf($filename)
{
  $lines = get-content $filename
  foreach($line in $lines){
    # Remove comments and blank lines.
    if($line -match "^$"){ continue }
    if($line -match "^\s*;"){ continue }

    $param = $line.split("=",2)

    $params[$param[0]] = $param[1]
  }
}

read_conf ".\sindan.conf"

if ($params["DEBUG_LOG"]) {
    $debugValue = $params["DEBUG_LOG"].ToString().Trim().ToLower()
    $debugEnabled = ($debugValue -eq "1" -or $debugValue -eq "true" -or $debugValue -eq "yes" -or $debugValue -eq "on")
}

if ($debugEnabled) {
    if (-not (Test-Path $debugLogDir)) {
        New-Item -ItemType Directory -Path $debugLogDir -Force | Out-Null
    }
    $debugLogPath = Join-Path $debugLogDir ("sindan_debug_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    Start-Transcript -Path $debugLogPath -Force | Out-Null
    Write-Host "debug log file: $debugLogPath"
}

if (-not $params["CAMPAIGN_ENDPOINT"]) {
    throw "CAMPAIGN_ENDPOINT is missing in sindan.conf"
}

$campaignEndpoint = $params["CAMPAIGN_ENDPOINT"]

if ($params["DO_SPEEDTEST"]) {
    $speedtestValue = $params["DO_SPEEDTEST"].ToString().Trim().ToLower()
    $doSpeedtest = ($speedtestValue -eq "1" -or $speedtestValue -eq "true" -or $speedtestValue -eq "yes" -or $speedtestValue -eq "on")
}

if ($params["SPEEDTEST_CMD"]) {
    $speedtestCmd = $params["SPEEDTEST_CMD"].ToString().Trim()
}

if ($params["ST_SRVS"]) {
    $speedtestServerIds = @($params["ST_SRVS"].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

function resolve_check($fqdns, $dns_server, $group, $type, $dnstype) {
   foreach ($fqdn in $fqdns) {
            $dns_results = $null
            $elapsedMsList = @()
            $lastError = ""

            for ($i = 0; $i -lt 3; $i++) {
                try {
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()
                    if ($dns_server) {
                        $probe_results = Resolve-DnsName $fqdn $dnstype -DnsOnly -Server $dns_server -ErrorAction Stop
                    } else {
                        $probe_results = Resolve-DnsName $fqdn $dnstype -DnsOnly -ErrorAction Stop
                    }
                    $sw.Stop()
                    $elapsedMsList += [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
                    if (-not $dns_results) {
                        $dns_results = $probe_results
                    }
                } catch {
                    $lastError = $_.Exception.Message
                }
            }

            $result = 0
            if ($elapsedMsList.Count -gt 0) {
                $result = 1
            }

            $detail = ""
            if ($dns_results) {
                foreach ($dns_result in $dns_results) {
                    if ($dns_result.Section -eq 1) {
                        if ($dns_result.IPAddress) {
                            $detail = $detail + $dns_result.IPAddress + " "
                        } elseif ($dns_result.NameHost) {
                            $detail = $detail + $dns_result.NameHost + " "
                        }
                    }
                }
            }

            if ($detail -ne "") {
                write_json "dns" $group $type $result $detail.Trim()
            } elseif ($lastError -ne "") {
                write_json "dns" $group $type $params['FAIL'] ("(" + $fqdn + ") " + $lastError)
            }

            if ($elapsedMsList.Count -gt 0) {
                $minRtt = ($elapsedMsList | Measure-Object -Minimum).Minimum
                $maxRtt = ($elapsedMsList | Measure-Object -Maximum).Maximum
                $avgRtt = [math]::Round((($elapsedMsList | Measure-Object -Average).Average), 2)
                $dnsTarget = if ($dns_server) { $dns_server } else { "system-default" }
                $rttDetail = "fqdn=$fqdn dns=$dnsTarget min_ms=$minRtt avg_ms=$avgRtt max_ms=$maxRtt count=$($elapsedMsList.Count)"
                write_json "dns" $group ($type + "_rtt") $params['INFO'] $rttDetail
            }
    }
    
}

function ping_check($target_host, $layer, $group, $type) {
    foreach ($target in @($target_host)) {
        if ($null -eq $target) { continue }
        $target = $target.ToString().Trim()
        if ($target -eq "") { continue }

        $ver = if ($group -eq "IPv6") { "6" } else { "4" }
        $targetType = $type
        if ($type -match '^v[46]alive_(.+)$') {
            $targetType = $Matches[1]
        }
        $aliveType = "v${ver}alive_${targetType}"

        try {
            $ping = Test-Connection $target -Count 4 -ErrorAction Stop
            $statusCodes = @($ping.StatusCode)
            $okCount = @($statusCodes | Where-Object { $_ -eq 0 }).Count
            $result = if ($okCount -gt 0) { $params['SUCCESS'] } else { $params['FAIL'] }
            write_json $layer $group $type $result ("(" + $target + ") " + ($statusCodes -join ' '))
            write_json $layer $group $aliveType $result $target

            $rttList = @($ping | Where-Object { $_.StatusCode -eq 0 -and $null -ne $_.ResponseTime } | ForEach-Object { [double]$_.ResponseTime })
            if ($rttList.Count -gt 0) {
                $minRtt = ($rttList | Measure-Object -Minimum).Minimum
                $maxRtt = ($rttList | Measure-Object -Maximum).Maximum
                $avgRtt = [math]::Round((($rttList | Measure-Object -Average).Average), 2)

                $sumSq = 0.0
                foreach ($rtt in $rttList) {
                    $diff = [double]$rtt - [double]$avgRtt
                    $sumSq += ($diff * $diff)
                }
                $devRtt = [math]::Round([math]::Sqrt($sumSq / $rttList.Count), 2)

                $totalCount = [double]$statusCodes.Count
                $lossPct = if ($totalCount -gt 0) {
                    [math]::Round((($totalCount - [double]$okCount) / $totalCount) * 100.0, 2)
                } else {
                    100
                }

                $rttDetail = "target=$target min_ms=$minRtt avg_ms=$avgRtt max_ms=$maxRtt count=$($rttList.Count)"
                write_json $layer $group ($type + "_rtt") $params['INFO'] $rttDetail
                write_json $layer $group ("v${ver}rtt_${targetType}_min") $params['INFO'] $minRtt
                write_json $layer $group ("v${ver}rtt_${targetType}_ave") $params['INFO'] $avgRtt
                write_json $layer $group ("v${ver}rtt_${targetType}_max") $params['INFO'] $maxRtt
                write_json $layer $group ("v${ver}rtt_${targetType}_dev") $params['INFO'] $devRtt
                write_json $layer $group ("v${ver}loss_${targetType}") $params['INFO'] $lossPct
            }
        } catch {
            write_json $layer $group $type $params['FAIL'] ("(" + $target + ") " + $_.Exception.Message)
            write_json $layer $group $aliveType $params['FAIL'] $target
            write_json $layer $group ($type + "_rtt") $params['FAIL'] ("target=" + $target + " error=" + $_.Exception.Message)
        }
    }
}

function trace_check($target_host, $layer, $group, $type) {
    $ver = if ($group -eq "IPv6") { "6" } else { "4" }
    $targetType = $type
    if ($type -match '^v[46]trace_(.+)$') {
        $targetType = $Matches[1]
    }

    try {
        $traceArgs = @("-d", "-h", "15", "-w", "1000")
        if ($group -eq "IPv6") {
            $traceArgs += "-6"
        }
        $traceArgs += $target_host

        $traceOutput = (& tracert @traceArgs 2>&1 | Out-String)
        $traceOk = ($traceOutput -match "Trace complete|トレースを完了")
        $traceSummary = (($traceOutput -split "`r?`n") | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 5) -join " | "

        $pathHops = @()
        foreach ($line in ($traceOutput -split "`r?`n")) {
            if ($line -match '^\s*\d+\s+') {
                if ($group -eq "IPv6") {
                    $m = [regex]::Match($line, '([0-9a-fA-F:]{2,})')
                    if ($m.Success) { $pathHops += $m.Value }
                } else {
                    $m = [regex]::Match($line, '(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)')
                    if ($m.Success) { $pathHops += $m.Value }
                }
            }
        }
        $pathData = ($pathHops -join ',')

        if ($traceOk) {
            write_json $layer $group $type 1 $traceSummary
            write_json $layer $group ("v${ver}path_detail_${targetType}") $params['INFO'] $traceOutput.Trim()
            write_json $layer $group ("v${ver}path_${targetType}") $params['INFO'] $pathData
        } else {
            write_json $layer $group $type 0 $traceSummary
            write_json $layer $group ("v${ver}path_detail_${targetType}") $params['INFO'] $traceOutput.Trim()
        }
    } catch {
        write_json $layer $group $type 0 $_.Exception.Message
    }
}

function pmtud_check_v4($target_host, $layer, $group, $type, $ifMtu) {
    try {
        $ifMtuInt = 1500
        $tmp = 0
        if ([int]::TryParse($ifMtu.ToString(), [ref]$tmp) -and $tmp -gt 600) {
            $ifMtuInt = $tmp
        }

        $low = 548
        $high = [Math]::Max($low, $ifMtuInt - 28)
        $best = -1

        while ($low -le $high) {
            $mid = [int](($low + $high) / 2)
            $pingOutput = (& ping -n 1 -w 1000 -f -l $mid $target_host 2>&1 | Out-String)

            if ($pingOutput -match "TTL=|ttl=") {
                $best = $mid
                $low = $mid + 1
            } else {
                $high = $mid - 1
            }
        }

        if ($best -ge 0) {
            $pmtu = $best + 28
            write_json $layer $group $type 1 ("target=" + $target_host + " pmtu=" + $pmtu)
        } else {
            write_json $layer $group $type 0 ("target=" + $target_host + " pmtu=unknown")
        }
    } catch {
        write_json $layer $group $type 0 $_.Exception.Message
    }
}

function speedtest_check($layer) {
    if (-not (Get-Command $speedtestCmd -ErrorAction SilentlyContinue)) {
        write_json $layer "Dualstack" "speedtest" $params['FAIL'] ("command not found: " + $speedtestCmd)
        return
    }

    $targetIds = @("auto")
    if ($speedtestServerIds.Count -gt 0) {
        $targetIds = $speedtestServerIds
    }

    foreach ($targetId in $targetIds) {
        try {
            $args = @("--accept-license", "--accept-gdpr", "--format=json")
            if ($targetId -ne "auto") {
                $args += @("--server-id", $targetId)
            }

            $raw = (& $speedtestCmd @args 2>&1 | Out-String)
            $jsonStart = $raw.IndexOf("{")
            if ($jsonStart -lt 0) {
                throw "speedtest output is not JSON"
            }

            $speedtest = $raw.Substring($jsonStart) | ConvertFrom-Json
            $downloadMbps = [Math]::Round((($speedtest.download.bandwidth * 8) / 1000000), 2)
            $uploadMbps = [Math]::Round((($speedtest.upload.bandwidth * 8) / 1000000), 2)
            $latencyMs = [Math]::Round($speedtest.ping.latency, 2)
            $jitterMs = [Math]::Round($speedtest.ping.jitter, 2)
            $serverName = $speedtest.server.host

            write_json $layer "Dualstack" "speedtest" $params['SUCCESS'] ("target=" + $targetId + " server=" + $serverName)
            write_json $layer "Dualstack" "speedtest_download" $params['INFO'] $downloadMbps
            write_json $layer "Dualstack" "speedtest_upload" $params['INFO'] $uploadMbps
            write_json $layer "Dualstack" "speedtest_rtt" $params['INFO'] $latencyMs
            write_json $layer "Dualstack" "speedtest_jitter" $params['INFO'] $jitterMs
        } catch {
            write_json $layer "Dualstack" "speedtest" $params['FAIL'] $_.Exception.Message
        }
    }
}

function ConvertTo-DottedDecimalIP {
  <#
    .Synopsis
      Returns a dotted decimal IP address from either an unsigned 32-bit integer or a dotted binary string.
    .Description
      ConvertTo-DottedDecimalIP uses a regular expression match on the input string to convert to an IP address.
    .Parameter IPAddress
      A string representation of an IP address from either UInt32 or dotted binary.
  #>
 
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [String]$IPAddress
  )
  
  process {
    Switch -RegEx ($IPAddress) {
      "([01]{8}.){3}[01]{8}" {
        return [String]::Join('.', $( $IPAddress.Split('.') | ForEach-Object { [Convert]::ToUInt32($_, 2) } ))
      }
      "\d" {
        $IPAddress = [UInt32]$IPAddress
        $DottedIP = $( For ($i = 3; $i -gt -1; $i--) {
          $Remainder = $IPAddress % [Math]::Pow(256, $i)
          ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
          $IPAddress = $Remainder
         } )
       
        return [String]::Join('.', $DottedIP)
      }
      default {
        Write-Error "Cannot convert this format"
      }
    }
  }
}

function ConvertTo-Mask {
  <#
    .Synopsis
      Returns a dotted decimal subnet mask from a mask length.
    .Description
      ConvertTo-Mask returns a subnet mask in dotted decimal format from an integer value ranging 
      between 0 and 32. ConvertTo-Mask first creates a binary string from the length, converts 
      that to an unsigned 32-bit integer then calls ConvertTo-DottedDecimalIP to complete the operation.
    .Parameter MaskLength
      The number of bits which must be masked.
  #>
  
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [Alias("Length")]
    [ValidateRange(0, 32)]
    $MaskLength
  )
  
  Process {
    return ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $MaskLength).PadRight(32, "0")), 2))
  }
}
# Create UUID
$campaign_uuid = [guid]::NewGuid().ToString();

function write_json($layer, $group, $type, $result, $detail) {
    $json_data = @{  }

    $json_data["layer"] = $layer
    $json_data["log_group"] = $group
    $json_data["log_type"] = $type
    $json_data["result"] = $result
    $json_data["detail"] = $detail
    $json_data["occurred_at"] = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json_data["log_campaign_uuid"] = $campaign_uuid 

    echo (ConvertTo-Json $json_data) > ("log\sindan_"+$layer+"_"+$type+(Get-Date -Uformat %s)+".json")
}

$destructive=1

#################
##  Phase 0

# Set lock file

function GetCurrentSSID() {
    return (netsh wlan show interfaces) -Match 'Profile' -NotMatch 'Connection mode' -Replace "^\s+Profile\s+:\s+", "" -Replace "\s+$", ""
<#
    $WifiGUID = (Get-NetAdapter -Name $params["IFTYPE"]).interfaceGUID

    $InsterfacePath = "C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces\"
    foreach ($WifiGUID in $WifiGUIDs) {
        $WifiPath = Join-Path $InsterfacePath $WifiGUID
        $WifiXmls = Get-ChildItem -Path $WifiPath -Recurse
    }

    foreach ($wifixml in $WifiXmls) {
        [xml]$x = Get-Content -Path $wifixml.FullName
 
        [PSCustomObject]@{
        FileName = $WifiXml.FullName
        WifiName = $x.WLANProfile.Name
        ConnectionMode = $x.WLANProfile.ConnectionMode
        SSIDName = $x.WLANProfile.SSIDConfig.SSID.Name
        SSIDHex = $x.WLANProfile.SSIDConfig.SSID.Hex
        }
    }
#>
}

<#
function GetInterfaces() {
#    $body["layer"] = "Layer2";
    $body["occurred_at"] = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#    $body["log_group"] = "Wired"
#    $body["log_type"] = "Media"

    # Get devicename
    $interface = (Get-NetAdapter -Name $params["IFTYPE"]).interfaceGUID

    $body["detail"] = $interface

    # Get MAC address
    $body["mac_addr"] = ((Get-NetAdapter -Name $params["IFTYPE"]).MacAddress -replace ("-", ":")).ToLower()
    $body["log_campaign_uuid"] = $campaign_uuid    

    # Get OS version
    $body["os"]=(Get-WmiObject Win32_OperatingSystem).Name.split("|")[0]    
    
    # Register log_unit_id
    Invoke-RestMethod -Method Post -Uri http://fluentd.c.u-tokyo.ac.jp:8888/sindan.log_campaign -Body (ConvertTo-Json $body) -ContentType "application/json"
#    Invoke-RestMethod -Method Post -Uri http://fluentd.c.u-tokyo.ac.jp:8888/sindan.log -Body (ConvertTo-Json $body)  -ContentType "application/json"     

#    for($i=0; $i -lt $interfaces.Length ; $i++) {
#        $body["detail"] = $interfaces[$i]
#        Invoke-RestMethod -Method Post  -Uri http://fluentd.c.u-tokyo.ac.jp:8888/sindan.log -Body (ConvertTo-Json $body)  -ContentType "application/json" 
#    }
}
#>

function RegisterCampaingLog() {
    # Set Date
    $body["occurred_at"] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

    # Get MAC address
    $body["mac_addr"] = ((Get-NetAdapter -Name $params["IFTYPE"]).MacAddress -replace ("-", ":")).ToLower()
    $body["log_campaign_uuid"] = $campaign_uuid    

    # Get OS version
    $body["os"]=(Get-WmiObject Win32_OperatingSystem).Name.split("|")[0]    
    $body["ssid"] = GetCurrentSSID

    # Register campaign id
    Invoke-RestMethod -Method Post -Uri $campaignEndpoint -Body (ConvertTo-Json $body) -ContentType "application/json"

}


RegisterCampaingLog

##################
### Phase 1 
echo "Phase 1: Datalink Layer checking..."
$layer = "datalink"

if ($destructive) {
    # Record current ssid
    $ssid = GetCurrentSSID
#    echo $ssid_profile
    # If up/down
    echo "Interface Up/Down..."
    netsh interface set interface name= $params["IFTYPE"] admin=DISABLED
    sleep 1
    netsh interface set interface name= $params["IFTYPE"] admin=ENABLED

    # Change to recorded ssid
    sleep 5
    netsh wlan connect ssid=$ssid name=$ssid
}

sleep 2
$netadapter = Get-NetAdapter -Name $params["IFTYPE"]

# Check I/F status
$result = 0
if ($netadapter.Status -eq 'Up') {
    $result = 1
    $ifstatus = 'active'
} else {
    $result = 0
    $ifstatus = 'inactive'
}
write_json $layer "" ifstatus $result $ifstatus

# Get iftype
write_json $layer "" iftype $params['INFO'] $params['IFTYPE']

# Get ifmtu
write_json $layer "" ifmtu $params['INFO'] $netadapter.MtuSize

# Wi-Fi
if ($params["IFTYPE"] -eq 'Wi-Fi') {
    # Get Wi-Fi SSID
    $ssid = GetCurrentSSID
    write_json $layer "Wi-Fi" ssid $params['INFO'] $ssid

    # Get Wi-Fi RSSI
    $signalQualityRaw = (netsh wlan show interfaces) -Match 'Signal' -Replace "^\s+Signal\s+:\s+", "" -Replace "\s+$", "" -Replace "%", ""
    $signalQuality = 0
    if ([int]::TryParse($signalQualityRaw, [ref]$signalQuality)) {
        if ($signalQuality -lt 0) { $signalQuality = 0 }
        if ($signalQuality -gt 100) { $signalQuality = 100 }
        $rssi = [math]::Round(($signalQuality / 2.0) - 100)
    } else {
        $rssi = $params['FAIL']
    }
    write_json $layer "Wi-Fi" rssi $params['INFO'] $rssi

    # Get Wi-Fi noise
    write_json $layer "Wi-Fi" noise $params['INFO'] '-'

    # Get Wi-Fi rate
    write_json $layer 'Wi-Fi' rate $params['INFO'] (($netadapter.speed)/1000000)

    # Get Wi-Fi channel
    $channel = (netsh wlan show interfaces) -Match 'Channel' -Replace "^\s+Channel\s+:\s+", "" -Replace "\s+$", "" -Replace "%", ""
    write_json $layer "Wi-Fi" channel $params['INFO'] $channel

} else {
    # Get media type
}

#Get-NetAdapter

##################
### Phase 2 

echo "Phase 2: Interface Layer checking..."
$layer = 'interface'

$ifindex = (Get-NetIPInterface 'Wi-Fi' -AddressFamily IPv6).ifIndex

$ipinterface = Get-NetIPInterface $params["IFTYPE"] -AddressFamily 'IPv4'
$ip6interface = Get-NetIPInterface $params["IFTYPE"] -AddressFamily 'IPv6'
$ipconfig = (Get-NetIPConfiguration $params["IFTYPE"])

# Get if configuration
if ($ipinterface.Dhcp -eq 'Enabled') {
    $v4ifconf = 'dhcp'
} else {
    $v4ifconf = 'static'
}
write_json $layer 'IPv4' v4ifconf $params['INFO'] $v4ifconf

# Get IPv4 address
write_json $layer 'IPv4' v4addr $params['INFO'] $ipconfig.IPv4Address.IPAddress

# Get IPv4 netmask
write_json $layer 'IPv4' netmask $params['INFO'] (ConvertTo-Mask $ipconfig.IPv4Address.PrefixLength)

# Get IPv4 routers
$ipv4gateway = $ipconfig.IPv4DefaultGateway.NextHop
write_json $layer 'IPv4' v4routers $params['INFO'] $ipv4gateway

# Get IPv4 name servers
$ipv4nameserver = ((Get-NetIPConfiguration 'Wi-FI').DNSServer | Where-Object {$_.AddressFamily -eq 2}).ServerAddresses
write_json $layer 'IPv4' v4nameservers $params['INFO'] $ipv4nameserver

# Get IPv4 NTP servers

# Get IPv6 linklocal address
$v6addrs = (Get-NetIPAddress -InterfaceIndex $ifindex -AddressFamily IPv6)
foreach ($v6addr in $v6addrs) {
    if ($v6addr.PrefixOrigin -eq 'WellKnown') {
        write_json $layer 'IPv6' v6lladdr $params['INFO'] $v6addr.IPv6Address
    }
}
# Get IPv6 RA prefix

# if RA prefix present
    # Get IPv6 RA prefix flags
    # Get IPv6 RA flags
    # Get Ipv6 address
    # Get IPv6 routers
    $ipv6gateway = $ipconfig.IPv6DefaultGateway.NextHop
    write_json $layer 'IPv6' v6routers $params['INFO'] $ipv6gateway
    # Get IPv6 name servers

    # Get IPv6 NTP servers
# fi

# Report phase 2 results

##################
### Phase 3

echo "Phase 3: Localnet Layer checking..."
$layer = "localnet"

# Do ping to IPv4 routers
ping_check $ipv4gateway $layer 'IPv4' 'v4alive_router'

# Do ping to IPv4 nameservers
ping_check $ipv4nameserver $layer 'IPv4' 'v4alive_namesrv'

# Do ping to IPv6 routers
if ($ipv6gateway) {
    if (($ipv6gateway -match '^fe80:') -and ($ipv6gateway -notmatch '%') -and $ifindex) {
        $ipv6gateway = "$ipv6gateway%$ifindex"
    }
    ping_check $ipv6gateway $layer 'IPv6' 'v6alive_router'
}

# Do ping to IPv6 nameservers
if ($ipv6nameserver) {
    ping_check $ipv6nameserver $layer 'IPv6' 'v6alive_namesrv'
}

##################
### Phase 4
echo "Phase 4: Globalnet Layer checking..."
$layer="globalnet"

# Check PING_SRVS parameter
if ($params["PING_SRVS"]) {
    # Do ping to external IPv4 servers
    foreach ($target in ($params["PING_SRVS"] -split ",")) {
        $target = $target.Trim()
        if ($target -eq "") { continue }
        ping_check $target $layer 'IPv4' 'v4alive_srv'
        trace_check $target $layer 'IPv4' 'v4trace_srv'
        pmtud_check_v4 $target $layer 'IPv4' 'v4pmtud_srv' $netadapter.MtuSize
    }
}

# Check PING6_SRVS parameter
if ($params["PING6_SRVS"]) {
    # Do ping to external IPv6 servers
    foreach ($target in ($params["PING6_SRVS"] -split ",")) {
        $target = $target.Trim()
        if ($target -eq "") { continue }
        ping_check $target $layer 'IPv6' 'v6alive_srv'
        trace_check $target $layer 'IPv6' 'v6trace_srv'
        write_json $layer 'IPv6' 'v6pmtud_srv' $params['INFO'] 'not_implemented'
    }
}

##################
### Phase  5
echo "Phase 5: DNS Layer checking..."

$layer="dns"
# Clear dns local cache
echo "flushing DNS caches..."
Clear-DnsClientCache

# Check FQDNS parameter
if ($params["FQDNS"]) {
    $fqdns = $params["FQDNS"] -split ","

    # Do dns lookup for A record by IPv4
    resolve_check $fqdns "" 'IPv4' v4trans_a_namesrv 'A'

    # Do dns lookup for AAAA record by IPv4
    resolve_check $fqdns "" 'IPv4' v4trans_aaaa_namesrv 'AAAA'

    # Do dns lookup for A record by IPv6
    resolve_check $fqdns "" 'IPv6' v6trans_a_namesrv 'A'

    # Do dns lookup for AAAA record by IPv6
    resolve_check $fqdns "" 'IPv6' v6trans_aaaa_namesrv 'AAAA'

    # Check GPDNS[4|6] parameter
    if ($params["GPDNS4"]) {
        # Do dns lookup for A record by GPDNS4
        resolve_check $fqdns $params["GPDNS4"] 'IPv4' v4trans_a_namesrv 'A'

        # Do dns lookup for AAAA record by GPDNS4
        resolve_check $fqdns $params["GPDNS4"] 'IPv4' v4trans_aaaa_namesrv 'AAAA'
    }
    if ($params["GPDNS6"]) {
        # Do dns lookup for A record by GPDNS6
        resolve_check $fqdns $params["GPDNS6"] 'IPv6' v6trans_a_namesrv 'A'

        # Do dns lookup for AAAA record by GPDNS6
        resolve_check $fqdns $params["GPDNS6"] 'IPv6' v6trans_aaaa_namesrv 'AAAA'

    }

}

##################
### Phase 6
echo "Phase 6: Web Layer checking..."
$layer="web"

# Check V4WEB_SRVS parameter
if($params["V4WEB_SRVS"]) {

    foreach ($v4target in ($params["V4WEB_SRVS"] -split ',')) {
        $webresult = Invoke-WebRequest $v4target
        if ($webresult.StatusDescription -eq "OK") {
            $result = 1
        } else {
            $result = 0
        }
        write_json $layer 'IPv4' v4http_srv $result $webresult.StatusCode
    }
}

if($params["V6WEB_SRVS"]) {

    foreach ($v6target in ($params["V6WEB_SRVS"] -split ',')) {
        $webresult = Invoke-WebRequest $v6target
        if ($webresult.StatusDescription -eq "OK") {
            $result = 1
        } else {
            $result = 0
        }
        write_json $layer 'IPv6' v6http_srv $result $webresult.StatusCode
    }
}

##################
### Phase 7
echo "Phase 7: Application Layer checking..."
$layer="app"

if ($doSpeedtest) {
    speedtest_check $layer
}

# write log file

# remove lock file

if ($debugEnabled) {
    Stop-Transcript | Out-Null
}

exit 0



