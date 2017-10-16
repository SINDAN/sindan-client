# change to english locale
chcp 437

$params = @{  }
$body = @{ }

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

function resolve_check($fqdns, $dns_server, $group, $type, $dnstype) {
   foreach ($fqdn in $fqdns) {
            try {
                $result = 1
                if ($dns_server) {
                    $dns_results = Resolve-DnsName $fqdn $dnstype -DnsOnly -Server $dns_server
                } else {
                    $dns_results = Resolve-DnsName $fqdn $dnstype -DnsOnly
                }
            } catch {
                $result = 0
            }
            $detail = ""
            foreach ($dns_result in $dns_results) {
                if ($dns_result.Section -eq 1) {
                    if($dns_result.IPAddress) {
                        $detail = $detail + $dns_result.IPAddress
                        $detail = $detail + " "
                    }
                }
            }
            if ($detail -ne "") {
                write_json "dns" $group $type $result $detail
            }
    }
    
}

function ping_check($target_host, $layer, $group, $type) {
    $ping = Test-Connection $target_host
    if (($ping.StatusCode -join ' ') -eq "0 0 0 0") {
        write_json $layer $group $type 1 ("("+$target_host+")"+$ping.StatusCode -join ' ')
    } else {
        write_json $layer $group $type 0 ("("+$target_host+")"+$ping.StatusCode -join ' ')  
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
    Invoke-RestMethod -Method Post -Uri http://sindan-dev.c.u-tokyo.ac.jp:8888/sindan.log_campaign -Body (ConvertTo-Json $body) -ContentType "application/json"

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
    $rssi = (netsh wlan show interfaces) -Match 'Signal' -Replace "^\s+Signal\s+:\s+", "" -Replace "\s+$", "" -Replace "%", ""
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
        ping_check $target $layer 'IPv4' 'v4alive_srv'
    }
}

# Do traceroute to external IPv4 servers

# Check path MTU to external IPv4 servers

# Check PING6_SRVS parameter
if ($params["PING6_SRVS"]) {
    # Do ping to external IPv6 servers
    foreach ($target in ($params["PING6_SRVS"] -split ",")) {
        ping_check $target $layer 'IPv6' 'v6alive_srv'
    }
}

# Do traceroute to external IPv6 servers

# Check path MTU to external IPv6 servers

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

# write log file

# remove lock file

exit 0



