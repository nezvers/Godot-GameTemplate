# Guest side on Windows (official WireGuard client). See README.md.
#   powershell -ExecutionPolicy Bypass -File vlan_connect.ps1 <invite>   join the host's virtual LAN (rerun with a new invite if the host's address changed)
#   powershell -ExecutionPolicy Bypass -File vlan_connect.ps1            show info + the reply line to send back to the host
# Asks for admin. Installs WireGuard with winget if missing (vlan_disconnect.ps1 removes it again).
param([string]$Invite = "")
$ErrorActionPreference = "Stop"

$Name = "zsvlan"; $Net = "10.77.0"; $GamePort = 24565
$Port = if ($env:VLAN_PORT) { [int]$env:VLAN_PORT } else { 51820 }
$State = Join-Path $env:ProgramData "zs-vlan"
$WgExe = Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"
$Wg = Join-Path $env:ProgramFiles "WireGuard\wg.exe"
$Svc = 'WireGuardTunnel$' + $Name

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $a = @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Invite) { $a += $Invite }
    Start-Process powershell -Verb RunAs -ArgumentList $a
    exit
}

function Enc([string]$prefix, [string]$text) { "$prefix." + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($text)) }
function Dec([string]$prefix, [string]$line) {
    if (-not $line.StartsWith("$prefix.")) { throw "not a $prefix line: $line" }
    [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($line.Substring($prefix.Length + 1))).Split(" ")
}
# Public IPv6 = the source address Windows uses toward the internet (no external lookup). "-" if none.
function MyV6 {
    try {
        $a = (Find-NetRoute -RemoteIPAddress "2606:4700:4700::1111" -ErrorAction Stop | Where-Object { $_.IPAddress } | Select-Object -First 1).IPAddress
        if ($a -and $a -notmatch '^(fe80|fc|fd)') { return $a }
    } catch {}
    "-"
}
# Public IPv4 (fallback only): $env:VLAN_IPV4 = addr sets it, "none" skips; else one lookup at api.ipify.org.
function MyV4 {
    if ($env:VLAN_IPV4) { if ($env:VLAN_IPV4 -eq "none") { return "-" } return $env:VLAN_IPV4 }
    try { $a = "$(Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 4)".Trim(); if ($a -match '^\d+\.\d+\.\d+\.\d+$') { return $a } } catch {}
    "-"
}
# IPv6 when both sides have it, else the host's IPv4.
function PickEp($hv6, $hv4, $hport, $mv6) {
    if ($hv6 -ne "-" -and $mv6 -ne "-") { return "[${hv6}]:${hport}" }
    if ($hv4 -ne "-") { return "${hv4}:${hport}" }
    throw "host has no address usable from here (no IPv6 on one side, no IPv4 in invite)"
}
function GuestPub { ((Get-Content "$State\guest.key" -Raw).Trim() | & $Wg pubkey).Trim() }

function Show {
    $hpub, $hport, $slot, $hv6, $hv4 = Dec "zsi1" (Get-Content "$State\invite" -Raw).Trim()
    $s = Get-Service $Svc -ErrorAction SilentlyContinue
    $hs = "none yet (host must add your reply)"
    $line = & $Wg show $Name latest-handshakes 2>$null
    if ($line) {
        $t = [int64](("$line" -split "\s+")[1])
        if ($t -gt 0) { $hs = "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $t)s ago (connected)" }
    }
    $ping = if (Test-Connection -ComputerName "$Net.1" -Count 1 -Quiet) { "online" } else { "no reply" }
    Write-Host "== zs-vlan guest (WireGuard, no servers) =="
    Write-Host "tunnel    : $Name ($(if ($s) { $s.Status } else { 'not installed' }))"
    Write-Host "this PC   : $Net.$slot"
    Write-Host "host      : $Net.1 via $(PickEp $hv6 $hv4 $hport (MyV6))  ($ping)"
    Write-Host "handshake : $hs"
    Write-Host "game      : join $Net.1:$GamePort"
    Write-Host ""
    Write-Host "reply - send this line back to the host (they run: vlan_up.sh add <reply>):"
    Write-Host ""
    Write-Host (Enc "zsr1" "$slot $(GuestPub) $Port $(MyV6) $(MyV4)")
}

if ($Invite) {
    $hpub, $hport, $slot, $hv6, $hv4 = Dec "zsi1" $Invite
    $ep = PickEp $hv6 $hv4 $hport (MyV6)

    if (-not (Test-Path $State)) {
        New-Item -ItemType Directory $State | Out-Null
        icacls $State /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" | Out-Null   # admins + SYSTEM only
    }
    if (-not (Test-Path $WgExe)) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "install WireGuard from https://www.wireguard.com/install/ and rerun" }
        winget install --id WireGuard.WireGuard -e --silent --accept-package-agreements --accept-source-agreements
        if (-not (Test-Path $WgExe)) { throw "WireGuard install failed" }
        Set-Content "$State\installed_wireguard" "1"
    }
    if (-not (Test-Path "$State\guest.key")) { Set-Content "$State\guest.key" (& $Wg genkey).Trim() }   # same key on rejoin
    Set-Content "$State\invite" $Invite
    $priv = (Get-Content "$State\guest.key" -Raw).Trim()
    $conf = "[Interface]`r`nPrivateKey = $priv`r`nAddress = $Net.$slot/24`r`nListenPort = $Port`r`n`r`n" +
            "[Peer]`r`nPublicKey = $hpub`r`nAllowedIPs = $Net.1/32`r`nEndpoint = $ep`r`nPersistentKeepalive = 25`r`n"
    [IO.File]::WriteAllText("$State\$Name.conf", $conf)

    if (Get-Service $Svc -ErrorAction SilentlyContinue) { & $WgExe /uninstalltunnelservice $Name; Start-Sleep 3 }
    & $WgExe /installtunnelservice "$State\$Name.conf"
    Start-Sleep 3

    if (-not (Get-NetFirewallRule -Group "zs-vlan" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "zs-vlan WireGuard UDP $Port" -Group "zs-vlan" -Direction Inbound -Protocol UDP -LocalPort $Port -Action Allow -Profile Any | Out-Null
        New-NetFirewallRule -DisplayName "zs-vlan tunnel" -Group "zs-vlan" -Direction Inbound -RemoteAddress "$Net.0/24" -Action Allow -Profile Any | Out-Null
    }
    Write-Host "connected (host sees you once they add your reply)."
    Write-Host ""
} elseif (-not (Test-Path "$State\invite")) {
    throw "usage: vlan_connect.ps1 <invite line from the host>"
}
Show
