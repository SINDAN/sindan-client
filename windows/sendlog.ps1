$ErrorActionPreference = "Stop"

$params = @{}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$confPath = Join-Path $scriptDir "sindan.conf"
$logDir = Join-Path $scriptDir "log"
$endpoint = $null
$lockFilePath = $null

function Read-Conf($filename) {
    $lines = Get-Content $filename
    foreach ($line in $lines) {
        # Remove comments and blank lines.
        if ($line -match "^\s*$") { continue }
        if ($line -match "^\s*[;#]") { continue }

        $param = $line.Split("=", 2)
        if ($param.Count -ne 2) { continue }

        $key = $param[0].Trim()
        $value = $param[1].Trim()
        if ($key -eq "") { continue }
        $params[$key] = $value
    }
}

Read-Conf $confPath

if (-not $params.ContainsKey("LOCKFILE_SENDLOG")) {
    throw "LOCKFILE_SENDLOG is missing in sindan.conf"
}

if (-not $params.ContainsKey("SENDLOG_ENDPOINT") -or [string]::IsNullOrWhiteSpace($params["SENDLOG_ENDPOINT"])) {
    throw "SENDLOG_ENDPOINT is missing in sindan.conf"
}

$endpoint = $params["SENDLOG_ENDPOINT"]

# Resolve relative path in config against script directory.
$lockFilePath = if ([System.IO.Path]::IsPathRooted($params["LOCKFILE_SENDLOG"])) {
    $params["LOCKFILE_SENDLOG"]
} else {
    Join-Path $scriptDir $params["LOCKFILE_SENDLOG"]
}

if (Test-Path $lockFilePath) {
    $lockContent = ""
    try {
        $lockContent = (Get-Content $lockFilePath -Raw).Trim()
    } catch {
        $lockContent = ""
    }

    $isRunning = $false
    $lockPid = 0

    if ([int]::TryParse($lockContent, [ref]$lockPid) -and $lockPid -gt 0) {
        try {
            $null = Get-Process -Id $lockPid -ErrorAction Stop
            $isRunning = $true
        } catch {
            $isRunning = $false
        }
    }

    if ($isRunning) {
        Write-Host "sendlog is already running (pid=$lockPid)"
        exit 1
    }

    Write-Host "stale lock file detected. removing: $lockFilePath"
    Remove-Item $lockFilePath -Force
}

try {
    Set-Content -Path $lockFilePath -Value $PID -Encoding ASCII -NoNewline

    if (-not (Test-Path $logDir)) {
        Write-Host "log directory not found: $logDir"
        exit 0
    }

    foreach ($jsonlog in (Get-ChildItem $logDir -File -Filter "*.json")) {
        $jsonPath = Join-Path $logDir $jsonlog.Name
        $canDelete = $false

        try {
            $raw = Get-Content $jsonPath -Encoding UTF8 -Raw
            $body = $raw | ConvertFrom-Json
            $jsonBody = ConvertTo-Json $body -Depth 20 -Compress

            Write-Host "send: $($jsonlog.Name)"
            Invoke-RestMethod -Method Post -Uri $endpoint -Body $jsonBody -ContentType "application/json" | Out-Null
            $canDelete = $true
        } catch {
            Write-Host "failed to send: $($jsonlog.Name)"
            Write-Host $_.Exception.Message
        }

        if ($canDelete) {
            Remove-Item $jsonPath -Force
        }
    }
} finally {
    if ($lockFilePath -and (Test-Path $lockFilePath)) {
        Remove-Item $lockFilePath -Force
    }
}