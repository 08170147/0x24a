param(
    [string]$RemoteUser,
    [string]$RemoteHost,
    [string]$RemotePort,
    [string]$RemoteRoot,
    [string]$TeamId,
    [string]$BundleId,
    [string]$ExportMethod,
    [string]$SshKey,
    [switch]$Reconfigure,
    [switch]$KeepRemote,
    [switch]$ResetConfig
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "v17 Auto Discovery IPv4 Byte Fix"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot "Builds"
$ConfigPath = Join-Path $PSScriptRoot "remote-mac.config.json"
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null

function Get-EnvValue([string]$Name) {
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($v)) { return $null }
    return $v
}

function Read-Config {
    if (!(Test-Path $ConfigPath)) { return $null }
    try {
        return Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
    } catch {
        Write-Warning "Saved configuration is invalid. A new configuration will be requested."
        return $null
    }
}

function Prompt-Required([string]$Label, [string]$Current, [string]$Default) {
    $value = $Current
    while ([string]::IsNullOrWhiteSpace($value)) {
        $suffix = if (![string]::IsNullOrWhiteSpace($Default)) { " [$Default]" } else { "" }
        $value = Read-Host "$Label$suffix"
        if ([string]::IsNullOrWhiteSpace($value) -and ![string]::IsNullOrWhiteSpace($Default)) { $value = $Default }
        if ([string]::IsNullOrWhiteSpace($value)) { Write-Host "  This value is required." -ForegroundColor Yellow }
    }
    return $value.Trim()
}

function Prompt-Optional([string]$Label, [string]$Current, [string]$Default) {
    $suffix = if (![string]::IsNullOrWhiteSpace($Default)) { " [$Default]" } else { "" }
    $value = Read-Host "$Label$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Prompt-ExportMethod([string]$Current) {
    $currentValue = $Current
    if ($currentValue -eq "app-store") { $currentValue = "app-store-connect" }
    if ($currentValue -in @("development","ad-hoc","app-store-connect")) { return $currentValue }

    Write-Host ""
    Write-Host "Build / IPA export type:"
    Write-Host "  1. development       - Development signed IPA"
    Write-Host "  2. ad-hoc             - Ad Hoc IPA for registered devices"
    Write-Host "  3. app-store-connect  - App Store Connect / TestFlight IPA"
    while ($true) {
        $choice = Read-Host "Select [1]"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
        switch ($choice) {
            "1" { return "development" }
            "2" { return "ad-hoc" }
            "3" { return "app-store-connect" }
            default { Write-Host "  Please enter 1, 2, or 3." -ForegroundColor Yellow }
        }
    }
}


function Normalize-RemoteEndpoint([string]$HostValue, [string]$PortValue) {
    $h = if ($null -eq $HostValue) { "" } else { $HostValue.Trim() }
    $p = if ($null -eq $PortValue) { "" } else { $PortValue.Trim() }

    # Accept host:port for normal hostnames / IPv4, but leave bracketed IPv6 intact.
    if ($h -match '^\[(.+)\]:(\d+)$') {
        if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "22") { $p = $Matches[2] }
        $h = $Matches[1]
    } elseif ($h -match '^((?:\d{1,3}\.){3}\d{1,3}):(\d+)$') {
        if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "22") { $p = $Matches[2] }
        $h = $Matches[1]
    } elseif ($h -match '^([^:]+):(\d+)$') {
        if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "22") { $p = $Matches[2] }
        $h = $Matches[1]
    }

    # Recover the common typo seen in first-run setup: 192.168.1.100.22
    # where the final .22 was intended to be the SSH port.
    if ($h -match '^((?:\d{1,3}\.){3}\d{1,3})\.(\d{1,5})$') {
        $candidateHost = $Matches[1]
        $candidatePort = [int]$Matches[2]
        if ($candidatePort -ge 1 -and $candidatePort -le 65535) {
            $octets = $candidateHost.Split('.') | ForEach-Object { [int]$_ }
            if (($octets | Where-Object { $_ -lt 0 -or $_ -gt 255 }).Count -eq 0) {
                Write-Warning "Remote host '$h' looks like an IPv4 address with the SSH port appended after a dot."
                Write-Host "  Interpreting it as host=$candidateHost port=$candidatePort" -ForegroundColor Yellow
                $h = $candidateHost
                if ([string]::IsNullOrWhiteSpace($p) -or $p -eq "22") { $p = [string]$candidatePort }
            }
        }
    }

    return @($h, $p)
}

function Validate-RemoteEndpoint([string]$HostValue, [string]$PortValue) {
    if ([string]::IsNullOrWhiteSpace($HostValue)) { throw "Remote Mac hostname / IP is empty." }
    if ($HostValue -match '[\s/]') { throw "Remote Mac hostname / IP contains invalid whitespace or '/': $HostValue" }
    if ($HostValue -match '^((?:\d{1,3}\.){4,}\d*)$') { throw "Remote Mac hostname / IP looks malformed: $HostValue" }
    $portNumber = 0
    if (-not [int]::TryParse($PortValue, [ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) {
        throw "SSH port must be a number from 1 to 65535. Current value: $PortValue"
    }
}


function Test-TcpPort([string]$HostValue, [int]$PortValue, [int]$TimeoutMs = 700) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($HostValue, $PortValue)
        if ($task.Wait($TimeoutMs) -and $client.Connected) { return $true }
        return $false
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Convert-IPv4ToUInt32([string]$Address) {
    $bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    if ($bytes.Length -ne 4) { throw "Only IPv4 addresses are supported for automatic discovery: $Address" }
    return [uint32]([BitConverter]::ToUInt32(@($bytes[3], $bytes[2], $bytes[1], $bytes[0]), 0))
}

function Convert-UInt32ToIPv4([uint32]$Value) {
    # Avoid PowerShell -band/-shr expression coercion. .NET returns the
    # UInt32 bytes directly; reverse on little-endian hosts for IPv4 order.
    [byte[]]$bytes = [BitConverter]::GetBytes($Value)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Get-ActiveIPv4Network {
    $configs = Get-NetIPConfiguration -ErrorAction Stop | Where-Object {
        $_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up'
    }
    $cfg = $configs | Where-Object {
        $_.InterfaceAlias -match 'Wi-Fi|WiFi|Wireless|Ethernet'
    } | Select-Object -First 1
    if ($null -eq $cfg) { $cfg = $configs | Select-Object -First 1 }
    if ($null -eq $cfg) { throw "Could not find an active IPv4 interface with a default gateway." }

    $addr = $cfg.IPv4Address | Select-Object -First 1
    $ip = [string]$addr.IPAddress
    $prefix = [int]$addr.PrefixLength
    if ([string]::IsNullOrWhiteSpace($ip) -or $prefix -lt 16 -or $prefix -gt 30) {
        throw "Automatic discovery requires an IPv4 prefix length between /16 and /30. Found $ip/$prefix."
    }

    [uint32]$ipInt = Convert-IPv4ToUInt32 $ip
    # Build the IPv4 netmask without shifting a UInt64 left past bit 63.
    # The previous implementation overflowed for normal prefixes such as /24.
    [int64]$hostCount = [int64][math]::Pow(2, (32 - $prefix))
    [int64]$mask64 = 4294967295 - ($hostCount - 1)
    [uint32]$mask = [uint32]$mask64
    [uint32]$network = $ipInt -band $mask
    [uint32]$broadcast = [uint32]([int64]$network + $hostCount - 1)

    return [pscustomobject]@{
        InterfaceAlias = $cfg.InterfaceAlias
        IP = $ip
        PrefixLength = $prefix
        Network = Convert-UInt32ToIPv4 $network
        Broadcast = Convert-UInt32ToIPv4 $broadcast
        NetworkInt = $network
        BroadcastInt = $broadcast
    }
}

function Find-SSHHosts {
    param(
        [int]$Port = 22,
        [int]$TimeoutMs = 700
    )

    $net = Get-ActiveIPv4Network
    Write-Host "" 
    Write-Host "== Auto-discover SSH hosts ==" -ForegroundColor Cyan
    Write-Host "Interface : $($net.InterfaceAlias)"
    Write-Host "Windows IP: $($net.IP)/$($net.PrefixLength)"
    Write-Host "Subnet    : $($net.Network)/$($net.PrefixLength)"
    Write-Host "Scanning TCP/$Port ..." -ForegroundColor Yellow

    $entries = New-Object System.Collections.Generic.List[object]
    $tasks = New-Object System.Collections.Generic.List[object]
    for ([uint64]$n = [uint64]$net.NetworkInt + 1; $n -lt [uint64]$net.BroadcastInt; $n++) {
        [uint32]$hostInt = [uint32]$n
        if ($hostInt -eq [uint32](Convert-IPv4ToUInt32 $net.IP)) { continue }
        $hostIp = Convert-UInt32ToIPv4 $hostInt
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $client.ConnectAsync($hostIp, $Port)
            $entries.Add([pscustomobject]@{ IP=$hostIp; Client=$client; Task=$task })
            $tasks.Add($task)
        } catch {
            $client.Dispose()
        }
    }

    if ($tasks.Count -gt 0) {
        try { [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$tasks, $TimeoutMs) | Out-Null } catch { }
    }

    $found = @($entries | Where-Object { $_.Client.Connected } | ForEach-Object { $_.IP })
    foreach ($entry in $entries) { $entry.Client.Dispose() }

    if ($found.Count -eq 0) {
        Write-Host "No TCP/$Port hosts found on $($net.Network)/$($net.PrefixLength)." -ForegroundColor Yellow
        return @()
    }

    Write-Host "" 
    Write-Host "SSH port $Port is open on:" -ForegroundColor Green
    for ($i=0; $i -lt $found.Count; $i++) {
        Write-Host ("  {0}. {1}:{2}" -f ($i + 1), $found[$i], $Port)
    }
    return $found
}

function Select-DiscoveredSSHHost([string]$CurrentHost) {
    $found = @(Find-SSHHosts)
    if ($found.Count -eq 0) { return $null }
    if ($found.Count -eq 1) {
        $choice = Read-Host "Use $($found[0]) as Remote Mac? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^[Yy]') { return $found[0] }
        return $null
    }
    while ($true) {
        $choice = Read-Host "Select SSH host number, or Enter to keep '$CurrentHost'"
        if ([string]::IsNullOrWhiteSpace($choice)) { return $null }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $found.Count) {
            return $found[$number - 1]
        }
        Write-Host "  Please enter a number from 1 to $($found.Count)." -ForegroundColor Yellow
    }
}

function Save-Config($Config) {
    $Config | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigPath -Encoding utf8
}

$config = Read-Config
$hasConfig = $null -ne $config

if ($ResetConfig -and (Test-Path $ConfigPath)) {
    Remove-Item -LiteralPath $ConfigPath -Force
    $config = $null
    $hasConfig = $false
    Write-Host "Saved configuration removed. Starting first-run setup." -ForegroundColor Yellow
}

if ($Reconfigure -or !$hasConfig) {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " KanadeDX Remote Mac first-run configuration" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Enter the SSH connection and Apple signing settings."
    Write-Host "SSH passwords/private keys are NOT saved by this script."
    Write-Host ""
}

function Pick([string]$Explicit, [string]$EnvName, [object]$Saved, [string]$Default) {
    if (![string]::IsNullOrWhiteSpace($Explicit)) { return $Explicit }
    $env = Get-EnvValue $EnvName
    if (![string]::IsNullOrWhiteSpace($env)) { return $env }
    if ($null -ne $Saved -and ![string]::IsNullOrWhiteSpace([string]$Saved)) { return [string]$Saved }
    return $Default
}

$RemoteUser = Pick $RemoteUser "KDX_REMOTE_USER" $(if($config){$config.RemoteUser}) $null
$RemoteHost = Pick $RemoteHost "KDX_REMOTE_HOST" $(if($config){$config.RemoteHost}) $null
$RemotePort = Pick $RemotePort "KDX_REMOTE_PORT" $(if($config){$config.RemotePort}) "22"
$RemoteRoot = Pick $RemoteRoot "KDX_REMOTE_ROOT" $(if($config){$config.RemoteRoot}) "~/KanadeDXRemoteBuild"
$TeamId = Pick $TeamId "KDX_TEAM_ID" $(if($config){$config.TeamId}) $null
$BundleId = Pick $BundleId "KDX_BUNDLE_ID" $(if($config){$config.BundleId}) "app.KanadeDX"
$ExportMethod = Pick $ExportMethod "KDX_EXPORT_METHOD" $(if($config){$config.ExportMethod}) $null
$SshKey = Pick $SshKey "KDX_SSH_KEY" $(if($config){$config.SshKey}) ""

# A previous setup may have accidentally stored the Team ID in the SSH-key field.
# Treat a missing saved key as non-fatal and fall back to the normal OpenSSH agent/default key.
if (![string]::IsNullOrWhiteSpace($SshKey) -and !(Test-Path -LiteralPath $SshKey -PathType Leaf)) {
    Write-Warning "Saved SSH key path does not exist: $SshKey"
    Write-Host "Ignoring the invalid SSH key and using Windows OpenSSH default authentication." -ForegroundColor Yellow
    $SshKey = ""
    if ($hasConfig) {
        $config.SshKey = ""
        Save-Config $config
        Write-Host "Saved configuration cleaned: SshKey is now empty." -ForegroundColor Green
    }
}

$NeedsSetup = $Reconfigure -or !$hasConfig -or
    [string]::IsNullOrWhiteSpace($RemoteUser) -or
    [string]::IsNullOrWhiteSpace($RemoteHost) -or
    [string]::IsNullOrWhiteSpace($TeamId)

if ($NeedsSetup) {
    $RemoteUser = Prompt-Required "Remote Mac username" $RemoteUser ""
    if ([string]::IsNullOrWhiteSpace($RemoteHost)) {
        $auto = Read-Host "Auto-discover a Mac with SSH port 22 on this Windows network? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($auto) -or $auto -match "^[Yy]") {
            $discovered = Select-DiscoveredSSHHost ""
            if (![string]::IsNullOrWhiteSpace($discovered)) { $RemoteHost = $discovered }
        }
    }
    $RemoteHost = Prompt-Required "Remote Mac hostname / IP" $RemoteHost ""
    $RemotePort = Prompt-Required "SSH port" $RemotePort "22"
    $TeamId = Prompt-Required "Apple Developer Team ID" $TeamId ""
    $BundleId = Prompt-Required "Bundle ID" $BundleId "app.KanadeDX"
    $RemoteRoot = Prompt-Required "Remote build directory" $RemoteRoot "~/KanadeDXRemoteBuild"
    $SshKey = Prompt-Optional "SSH private key path (optional)" $SshKey ""
    $endpoint = Normalize-RemoteEndpoint $RemoteHost $RemotePort
    $RemoteHost = $endpoint[0]
    $RemotePort = $endpoint[1]
    Validate-RemoteEndpoint $RemoteHost $RemotePort
    if (![string]::IsNullOrWhiteSpace($SshKey) -and !(Test-Path -LiteralPath $SshKey -PathType Leaf)) {
        Write-Host "  SSH key file not found; continuing without an explicit key." -ForegroundColor Yellow
        $SshKey = ""
    }
    $ExportMethod = Prompt-ExportMethod $ExportMethod

    $config = [ordered]@{
        RemoteUser = $RemoteUser
        RemoteHost = $RemoteHost
        RemotePort = $RemotePort
        RemoteRoot = $RemoteRoot
        TeamId = $TeamId
        BundleId = $BundleId
        ExportMethod = $ExportMethod
        SshKey = $SshKey
    }
    Save-Config $config
    Write-Host ""
    Write-Host "Settings saved to: $ConfigPath" -ForegroundColor Green
} else {
    # Existing configuration is complete; normalize and validate its endpoint before use.
    $endpoint = Normalize-RemoteEndpoint $RemoteHost $RemotePort
    $RemoteHost = $endpoint[0]
    $RemotePort = $endpoint[1]
    Validate-RemoteEndpoint $RemoteHost $RemotePort
    $ExportMethod = Prompt-ExportMethod $ExportMethod
    if ($ExportMethod -ne $config.ExportMethod) {
        $config.ExportMethod = $ExportMethod
        Save-Config $config
    }
    Write-Host "Using saved Remote Mac settings from: $ConfigPath" -ForegroundColor Green
}

# Always persist the normalized endpoint and current settings.
if ($null -eq $config) { $config = [ordered]@{} }
if ($true) {
    $config.RemoteHost = $RemoteHost
    $config.RemotePort = $RemotePort
    $config.RemoteUser = $RemoteUser
    $config.TeamId = $TeamId
    $config.BundleId = $BundleId
    $config.RemoteRoot = $RemoteRoot
    $config.ExportMethod = $ExportMethod
    $config.SshKey = $SshKey
    Save-Config $config
}

if ($ExportMethod -eq "app-store") { $ExportMethod = "app-store-connect" }
if ($ExportMethod -notin @("development","ad-hoc","app-store-connect")) {
    throw "Export method must be development, ad-hoc, or app-store-connect."
}

foreach ($pair in @(
    @{Name="REMOTE_USER";Value=$RemoteUser},
    @{Name="REMOTE_HOST";Value=$RemoteHost},
    @{Name="REMOTE_PORT";Value=$RemotePort},
    @{Name="TEAM_ID";Value=$TeamId},
    @{Name="BUNDLE_ID";Value=$BundleId}
)) {
    if ([string]::IsNullOrWhiteSpace($pair.Value)) { throw "Missing $($pair.Name)." }
}

Write-Host ""
# Validate SSH connectivity before packaging/uploading a large Unity project.
if (!(Test-TcpPort $RemoteHost ([int]$RemotePort) 900)) {
    Write-Host "SSH connection test failed: $RemoteHost`:$RemotePort" -ForegroundColor Yellow
    $auto = Read-Host "Scan this Windows network for another SSH host? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($auto) -or $auto -match "^[Yy]") {
        $discovered = Select-DiscoveredSSHHost $RemoteHost
        if (![string]::IsNullOrWhiteSpace($discovered) -and $discovered -ne $RemoteHost) {
            $RemoteHost = $discovered
            $config.RemoteHost = $RemoteHost
            Save-Config $config
            Write-Host "Remote Mac changed to $RemoteHost and saved." -ForegroundColor Green
        }
    }
    if (!(Test-TcpPort $RemoteHost ([int]$RemotePort) 1200)) {
        throw "No reachable SSH service on $RemoteHost`:$RemotePort. Connect Windows and the Mac to the same LAN, enable Remote Login on the Mac, or select the correct discovered host."
    }
}

Write-Host "SSH connectivity: OK ($RemoteHost`:$RemotePort)" -ForegroundColor Green
Write-Host ""
Write-Host "== Remote build configuration [$ScriptVersion] ==" -ForegroundColor Cyan
Write-Host "Remote : $RemoteUser@$RemoteHost`:$RemotePort"
Write-Host "Team   : $TeamId"
Write-Host "Bundle : $BundleId"
Write-Host "Method : $ExportMethod"
if ([string]::IsNullOrWhiteSpace($SshKey)) {
    Write-Host "SSH key: Windows OpenSSH default/agent"
} else {
    Write-Host "SSH key: $SshKey"
}
Write-Host ""

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zip = Join-Path $env:TEMP "KanadeDX-$stamp.zip"
$remoteZip = "$RemoteRoot/incoming/KanadeDX-$stamp.zip"
$remoteScript = "$RemoteRoot/run-build.sh"
$remoteIpa = "$RemoteRoot/out/KanadeDX.ipa"
$outIpa = Join-Path $BuildRoot "KanadeDX.ipa"

Write-Host "== 1/4 Package Unity project =="
if (Test-Path $zip) { Remove-Item $zip -Force }
# Do not upload previous build artifacts; they can contain a large IPA/archive.
$packageItems = Get-ChildItem -LiteralPath $ProjectRoot -Force | Where-Object { $_.Name -notin @("Builds", ".git") }
Compress-Archive -Path $packageItems.FullName -DestinationPath $zip -Force

$sshTarget = "$RemoteUser@$RemoteHost"
$sshBase = @()
$scpBase = @()
if (![string]::IsNullOrWhiteSpace($SshKey)) {
    if (!(Test-Path $SshKey)) { throw "SSH key not found: $SshKey" }
    $sshBase += @("-i", $SshKey)
    $scpBase += @("-i", $SshKey)
}
$ssh = $sshBase + @("-p", $RemotePort, $sshTarget)
$scp = $scpBase + @("-P", $RemotePort)

Write-Host "== 2/4 Upload to remote Mac =="
# Do not quote ~ so the remote shell can expand it when RemoteRoot uses ~/...
& ssh @ssh "mkdir -p $RemoteRoot/incoming $RemoteRoot/out $RemoteRoot/work"
if ($LASTEXITCODE -ne 0) { throw "Remote directory setup failed." }
& scp @scp $zip "${sshTarget}:$remoteZip"
if ($LASTEXITCODE -ne 0) { throw "SCP upload failed." }

$scriptLocal = Join-Path $env:TEMP "kdx-run-build-$stamp.sh"
$teamQ = $TeamId.Replace("'", "'\\''")
$bundleQ = $BundleId.Replace("'", "'\\''")
$methodQ = $ExportMethod.Replace("'", "'\\''")
if ($RemoteRoot -match '^~/(.*)$') {
    $remoteRootSuffix = $Matches[1].Replace('\"', '\\"')
    $rootAssignment = '"$HOME/' + $remoteRootSuffix + '"'
} else {
    $rootQ = $RemoteRoot.Replace("'", "'\\''")
    $rootAssignment = "'$rootQ'"
}
$zipQ = $remoteZip.Replace("'", "'\\''")
@"
#!/bin/bash
set -euo pipefail
REMOTE_ROOT=$rootAssignment
ZIP='$zipQ'
WORK="\$REMOTE_ROOT/work/KanadeDX-$stamp"
OUT="\$REMOTE_ROOT/out"
rm -rf "\$WORK"
mkdir -p "\$WORK" "\$OUT"
unzip -q "\$ZIP" -d "\$WORK"
cd "\$WORK"
export TEAM_ID='$teamQ'
export BUNDLE_ID='$bundleQ'
export EXPORT_METHOD='$methodQ'
export ALLOW_PROVISIONING_UPDATES=1
bash ./Tools/build_ipa.sh
cp -f Builds/KanadeDX.ipa "\$OUT/KanadeDX.ipa"
bash ./Tools/verify_ipa.sh "\$OUT/KanadeDX.ipa" '$bundleQ' '$teamQ'
echo "REMOTE_BUILD_SUCCESS=1"
"@ | ForEach-Object { [System.IO.File]::WriteAllText($scriptLocal, $_, (New-Object System.Text.UTF8Encoding($false))) }

Write-Host "== 3/4 Run Unity + Xcode on remote Mac =="
& scp @scp $scriptLocal "${sshTarget}:$remoteScript"
if ($LASTEXITCODE -ne 0) { throw "Build script upload failed." }
& ssh @ssh "chmod +x '$remoteScript' && bash '$remoteScript'"
if ($LASTEXITCODE -ne 0) { throw "Remote Mac build failed." }

Write-Host "== 4/4 Download verified IPA =="
if (Test-Path $outIpa) { Remove-Item $outIpa -Force }
& scp @scp "${sshTarget}:$remoteIpa" $outIpa
if ($LASTEXITCODE -ne 0) { throw "SCP download failed." }
if (!(Test-Path $outIpa)) { throw "IPA was not downloaded." }
$size = (Get-Item $outIpa).Length
if ($size -lt 100000) { throw "IPA is unexpectedly small: $size bytes." }

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " SUCCESS: verified IPA returned to Windows" -ForegroundColor Green
Write-Host " IPA : $outIpa"
Write-Host " Size: $size bytes"
Write-Host "===============================================" -ForegroundColor Green

if (-not $KeepRemote) {
    & ssh @ssh "rm -f '$remoteZip' '$remoteScript' '$remoteIpa'"
}
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Remove-Item $scriptLocal -Force -ErrorAction SilentlyContinue
