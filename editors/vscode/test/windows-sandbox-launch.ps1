param(
  [Parameter(Mandatory=$true)][string]$CaseDirectory,
  [int]$TimeoutSeconds = 600,
  [switch]$LifecycleOnly
)
$ErrorActionPreference = 'Stop'
$casePath = (Resolve-Path -LiteralPath $CaseDirectory).Path
$inputPath = Join-Path $casePath 'input'
$outputPath = Join-Path $casePath 'output'
$configuration = Join-Path $casePath 'rune.wsb'
foreach ($directory in @($casePath,$inputPath,$outputPath)) {
  if ((Get-Item -LiteralPath $directory).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Sandbox test directories must not be reparse points.' }
}
[xml]$policy = Get-Content -LiteralPath $configuration -Raw
$maps = @($policy.SelectNodes('/Configuration/MappedFolders/MappedFolder'))
if ($maps.Count -ne 2 -or $policy.SelectSingleNode('/Configuration/Networking').InnerText -cne 'Disable' -or $policy.SelectSingleNode('/Configuration/ClipboardRedirection').InnerText -cne 'Disable') { throw 'Expected isolated test Sandbox policy.' }
foreach ($entry in @(@('C:\Inputs',$inputPath,'true'),@('C:\Results',$outputPath,'false'))) {
  $mapping = @($maps | Where-Object { $_.SelectSingleNode('SandboxFolder').InnerText -eq $entry[0] })
  if ($mapping.Count -ne 1 -or $mapping[0].SelectSingleNode('HostFolder').InnerText -ne $entry[1] -or $mapping[0].SelectSingleNode('ReadOnly').InnerText -cne $entry[2]) { throw 'Unexpected Sandbox folder mapping.' }
}
$owned = @{}
$minimized = @{}
$guestConfirmed = $false
$cleanupConfirmed = $false
$launchTime = Get-Date
$launcher = $null
$outcome = $null
if (-not ('RuneSandboxWindow' -as [type])) { Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RuneSandboxWindow {
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr window, int command);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
}
'@
}
$lock = New-Object Threading.Mutex($false,'Local\RuneVscodeSandboxTest')
if (-not $lock.WaitOne(0)) { $lock.Dispose(); throw 'Another Rune Sandbox test is running.' }
function SandboxProcesses {
  @(Get-CimInstance Win32_Process -Filter "Name LIKE 'WindowsSandbox%'" -ErrorAction Stop)
}
function SaveOwnership {
  $temporary = Join-Path $casePath 'ownership.json.tmp'
  @{nonce=$nonce;processes=@($owned.Values)} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $temporary
  Move-Item -LiteralPath $temporary -Destination (Join-Path $casePath 'ownership.json') -Force
}
function CaptureOwned {
  $rows = SandboxProcesses
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($row in $rows) {
      $processNumber = [int]$row.ProcessId
      if ($owned.ContainsKey($processNumber) -or $row.CreationDate -lt $launchTime) { continue }
      if (-not $guestConfirmed -and -not $owned.ContainsKey([int]$row.ParentProcessId)) { continue }
      try {
        $process = Get-Process -Id $processNumber -ErrorAction Stop
        if ($process.ProcessName -cne [IO.Path]::GetFileNameWithoutExtension($row.Name) -or
            [Math]::Abs($process.StartTime.ToUniversalTime().Ticks-$row.CreationDate.ToUniversalTime().Ticks) -gt 10000) { continue }
        $owned[$processNumber] = @{ id=$processNumber; ticks=$process.StartTime.ToUniversalTime().Ticks; name=$process.ProcessName }
        SaveOwnership
        $changed = $true
      } catch [Microsoft.PowerShell.Commands.ProcessCommandException] { }
    }
  }
  foreach ($proof in @($owned.Values)) {
    $process = Get-Process -Id $proof.id -ErrorAction SilentlyContinue
    if ($null -eq $process -or $process.HasExited -or $null -eq $process.StartTime -or $process.StartTime.ToUniversalTime().Ticks -ne $proof.ticks) { continue }
    $process.Refresh()
    $window = $process.MainWindowHandle
    if ($null -ne $window -and $window -ne [IntPtr]::Zero -and -not $minimized.ContainsKey($window.ToInt64())) {
      [void][RuneSandboxWindow]::ShowWindowAsync($window,7)
      if ([RuneSandboxWindow]::IsIconic($window)) { $minimized[$window.ToInt64()] = $true }
    }
  }
}
try {
  if ((SandboxProcesses).Count -ne 0) { throw 'An existing Windows Sandbox is running; leave it undisturbed.' }
  if ((Get-ChildItem -LiteralPath $outputPath -Force).Count -ne 0) { throw 'Sandbox results directory must be empty.' }
  $nonce = [guid]::NewGuid().ToString()
  @{nonce=$nonce;hostMachine=$env:COMPUTERNAME} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $inputPath 'test-owner.json')
  [IO.File]::Copy((Join-Path $PSScriptRoot 'windows-sandbox-guest.ps1'),(Join-Path $inputPath 'run.ps1'),$true)
  [IO.File]::Copy((Join-Path $PSScriptRoot 'editor-suite.cjs'),(Join-Path $inputPath 'editor-suite.cjs'),$true)
  $smoke = Join-Path $inputPath 'lifecycle-only'
  if ($LifecycleOnly) { Set-Content -LiteralPath $smoke -Value $nonce } else { Remove-Item -LiteralPath $smoke -ErrorAction SilentlyContinue }
  $launchTime = Get-Date
  $launcher = Start-Process (Join-Path ([Environment]::SystemDirectory) 'WindowsSandbox.exe') -ArgumentList ('"'+$configuration+'"') -WindowStyle Minimized -PassThru
  $owned[$launcher.Id] = @{id=$launcher.Id;ticks=$launcher.StartTime.ToUniversalTime().Ticks;name=$launcher.ProcessName}
  SaveOwnership
  $end = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $end) {
    $ready = Join-Path $outputPath 'ready.json'
    if (Test-Path -LiteralPath $ready) {
      try { $guestConfirmed = (Get-Content -LiteralPath $ready -Encoding UTF8 -Raw | ConvertFrom-Json).nonce -eq $nonce } catch { }
    }
    CaptureOwned
    $complete = Join-Path $outputPath 'complete.json'
    if ($guestConfirmed -and (Test-Path -LiteralPath $complete)) {
      try {
        if ((Get-Content -LiteralPath $complete -Encoding UTF8 -Raw | ConvertFrom-Json).nonce -eq $nonce) {
          $outcome = Get-Content -LiteralPath (Join-Path $outputPath 'result.json') -Encoding UTF8 -Raw | ConvertFrom-Json
          break
        }
      } catch { }
    }
    Start-Sleep -Milliseconds 250
  }
  if ($null -eq $outcome) { throw 'Sandbox did not finish the test within its deadline.' }
} finally {
  # A retained process handle and creation time prevent PID reuse from
  # redirecting cleanup. Never stop processes merely by their image name.
  $targets = @($owned.Values | Sort-Object { if ($_.name -eq 'WindowsSandboxClient') { 0 } else { 1 } })
  foreach ($proof in $targets) {
    $process = Get-Process -Id $proof.id -ErrorAction SilentlyContinue
    if ($null -eq $process) { continue }
    try {
      [void]$process.Handle
      if ($process.ProcessName -cne $proof.name -or $process.StartTime.ToUniversalTime().Ticks -ne $proof.ticks) { continue }
      $process.Refresh()
      $window = $process.MainWindowHandle
      if ($null -ne $window -and $window -ne [IntPtr]::Zero) { [void][RuneSandboxWindow]::ShowWindowAsync($window,0) }
      $process.Kill()
      [void]$process.WaitForExit(5000)
    } catch { Write-Warning ('Owned Sandbox cleanup: '+$_.Exception.Message) }
  }
  $remaining = @($owned.Values | Where-Object {
    $process = Get-Process -Id $_.id -ErrorAction SilentlyContinue
    $null -ne $process -and -not $process.HasExited -and $null -ne $process.StartTime -and $process.StartTime.ToUniversalTime().Ticks -eq $_.ticks
  })
  $cleanupConfirmed = $remaining.Count -eq 0
  @{nonce=$nonce;guestConfirmed=$guestConfirmed;minimizedWindows=$minimized.Count;ownedProcesses=@($owned.Values);ownedProcessesGone=$cleanupConfirmed;guestShutdownUsed=$false} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $outputPath 'lifecycle.json')
  $lock.ReleaseMutex()
  $lock.Dispose()
}
if (-not $cleanupConfirmed) { throw 'An owned Sandbox process has not exited.' }
if ($null -ne $outcome) { Write-Output ($outcome | ConvertTo-Json) }
if ($null -eq $outcome -or $outcome.status -ne 'PASS') { exit 1 }
