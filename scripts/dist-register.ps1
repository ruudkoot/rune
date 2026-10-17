# Start menu, PATH and uninstall registration for install.bat.
# Reads and writes the Path value without expanding it, so a value that
# contains %SystemRoot% stays that way.
param(
  [Parameter(Mandatory=$true)][string]$Prefix,
  [Parameter(Mandatory=$true)][string]$StartMenu,
  [Parameter(Mandatory=$true)][ValidateSet('User','Machine')][string]$Scope,
  [Parameter(Mandatory=$true)][string]$UninstKey,
  [Parameter(Mandatory=$true)][string]$Version,
  [switch]$Undo
)
$ErrorActionPreference = 'Stop'

function Broadcast-Environment {
  $sig = @'
using System;
using System.Runtime.InteropServices;
public static class RuneEnv {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr result);
}
'@
  try {
    Add-Type -TypeDefinition $sig -ErrorAction Stop
    $result = [UIntPtr]::Zero
    [void][RuneEnv]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
  } catch {
    Write-Warning "PATH was updated; new consoles may not see it until they are opened ($_)"
  }
}

function Path-Key {
  if ($Scope -eq 'User') {
    return @{ Hive = [Microsoft.Win32.Registry]::CurrentUser; Sub = 'Environment' }
  }
  return @{
    Hive = [Microsoft.Win32.Registry]::LocalMachine
    Sub = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
  }
}

function Normalize([string]$Path) {
  if ([string]::IsNullOrEmpty($Path)) { return '' }
  return $Path.Trim().TrimEnd('\').ToLowerInvariant()
}

function Update-Path([string]$BinDir, [bool]$Remove) {
  $where = Path-Key
  $key = $where.Hive.CreateSubKey($where.Sub)
  $raw = ''
  $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
  $exists = $true
  try {
    $null = $key.GetValueKind('Path')
    $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $kind = $key.GetValueKind('Path')
  } catch {
    $exists = $false
  }
  if (-not $exists) {
    if ($Remove) { return }
    $key.SetValue('Path', $BinDir, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    return
  }
  $want = Normalize $BinDir
  $parts = @($raw -split ';' | Where-Object { $_ -ne '' })
  $kept = @($parts | Where-Object { (Normalize $_) -ne $want })
  if ($Remove) {
    $next = $kept
  } elseif ($kept.Count -eq $parts.Count) {
    $next = @($parts) + $BinDir
  } else {
    return
  }
  $key.SetValue('Path', ($next -join ';'), $kind)
}

function Uninst-Hive([string]$Key) {
  if ($Key.StartsWith('HKCU\')) {
    return @{ Hive = [Microsoft.Win32.Registry]::CurrentUser; Sub = $Key.Substring(5) }
  }
  if ($Key.StartsWith('HKLM\')) {
    return @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Sub = $Key.Substring(5) }
  }
  throw "uninstall key $Key is neither HKCU nor HKLM"
}

$bindir = Join-Path $Prefix 'bin'
$shortcut = Join-Path $StartMenu 'Rune.lnk'
$repl = Join-Path $bindir 'rune-repl.cmd'
$icon = Join-Path $Prefix 'share\rune.ico'
$where = Uninst-Hive $UninstKey

if ($Undo) {
  if (Test-Path -LiteralPath $shortcut) { Remove-Item -LiteralPath $shortcut -Force }
  Update-Path $bindir $true
  try { $where.Hive.DeleteSubKeyTree($where.Sub, $false) } catch { }
  Broadcast-Environment
  exit 0
}

New-Item -ItemType Directory -Force -Path $StartMenu | Out-Null
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcut)
$link.TargetPath = $repl
$link.WorkingDirectory = $env:USERPROFILE
$link.Description = 'Rune REPL'
$link.IconLocation = "$icon,0"
$link.Save()

Update-Path $bindir $false
$key = $where.Hive.CreateSubKey($where.Sub)
$key.SetValue('DisplayName', 'Rune')
$key.SetValue('DisplayVersion', $Version)
$key.SetValue('InstallLocation', $Prefix)
$key.SetValue('UninstallString', "`"$Prefix\uninstall.bat`"")
Broadcast-Environment
