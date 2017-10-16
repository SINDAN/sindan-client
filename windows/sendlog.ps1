$params = @{  }

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

if ( Test-Path $params["LOCKFILE_SENDLOG"] ) {
    echo 'sendlog is already running'
    exit -1
} else {
    echo "0" > $params["LOCKFILE_SENDLOG"]
}

foreach ($jsonlog in (Get-ChildItem .\log)) {
    $notdelete = 0
    $body = Get-Content ("log\"+$jsonlog.Name) -Encoding UTF8 -Raw | ConvertFrom-Json
    
    try {
        echo (ConvertTo-Json $body)
        Invoke-RestMethod -Method Post -Uri http://fluentd.c.u-tokyo.ac.jp:8888/sindan.log -Body (ConvertTo-Json $body) -ContentType "application/json"
    } catch {
        $notdelete = 1
    }

    if ($notdelete -ne 1) {
        Remove-Item ("log\"+$jsonlog.Name)
    }
}

Remove-Item $params["LOCKFILE_SENDLOG"]