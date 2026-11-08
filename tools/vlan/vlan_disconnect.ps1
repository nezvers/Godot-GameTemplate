# Guest side on Windows: remove everything vlan_connect.ps1 made (tunnel, firewall rules, keys/state,
# and WireGuard itself if vlan_connect.ps1 installed it). See README.md.
#   powershell -ExecutionPolicy Bypass -File vlan_disconnect.ps1
$ErrorActionPreference = "Continue"

$Name = "zsvlan"
$State = Join-Path $env:ProgramData "zs-vlan"
$WgExe = Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"
$Svc = 'WireGuardTunnel$' + $Name

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    exit
}

if (Get-Service $Svc -ErrorAction SilentlyContinue) {
    & $WgExe /uninstalltunnelservice $Name; Start-Sleep 3
    Write-Host "removed tunnel $Name"
} else { Write-Host "no tunnel $Name" }

if (Get-NetFirewallRule -Group "zs-vlan" -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -Group "zs-vlan"; Write-Host "removed firewall rules (group zs-vlan)"
}

if (Test-Path "$State\installed_wireguard") {
    winget uninstall --id WireGuard.WireGuard -e --silent
    Write-Host "uninstalled WireGuard (it was installed by vlan_connect.ps1)"
}

if (Test-Path $State) { Remove-Item $State -Recurse -Force; Write-Host "removed $State" }
Write-Host "done."
