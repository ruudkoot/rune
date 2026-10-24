$ErrorActionPreference = 'Stop'
if ($env:USERNAME -ne 'WDAGUtilityAccount' -or -not (Test-Path C:\Inputs\fixture.tar)) { throw 'This script runs only inside the prepared Windows Sandbox guest.' }
$owner = Get-Content C:\Inputs\test-owner.json -Encoding UTF8 -Raw | ConvertFrom-Json
if ($env:COMPUTERNAME -eq $owner.hostMachine) { throw 'Host execution is forbidden.' }
@{nonce=$owner.nonce} | ConvertTo-Json | Set-Content -Encoding UTF8 C:\Results\ready.json
if (Test-Path C:\Inputs\lifecycle-only) {
  @{status='PASS';stage='lifecycle-only'} | ConvertTo-Json | Set-Content -Encoding UTF8 C:\Results\result.json
  @{nonce=$owner.nonce} | ConvertTo-Json | Set-Content -Encoding UTF8 C:\Results\complete.json
  exit 0
}
$stage = 'bootstrap'
$status = 'FAIL'
$codeVersion = 'unavailable'
Start-Transcript -Path C:\Results\bootstrap.log -Force
try {
  New-Item -ItemType Directory -Path C:\Tools\Code,C:\Work -Force | Out-Null
  & "$env:SystemRoot\System32\tar.exe" -xf C:\Inputs\code.tar -C C:\Tools\Code
  if ($LASTEXITCODE -ne 0) { throw 'portable Code extraction failed' }
  $manifests = @('C:\Tools\Code\resources\app\package.json') + @(Get-ChildItem C:\Tools\Code -Directory | ForEach-Object { Join-Path $_.FullName 'resources\app\package.json' })
  $manifests = @($manifests | Where-Object { Test-Path -LiteralPath $_ })
  if ($manifests.Count -ne 1) { throw 'cannot identify portable Code version' }
  $codeVersion = (Get-Content -LiteralPath $manifests[0] -Encoding UTF8 -Raw | ConvertFrom-Json).version
  & "$env:SystemRoot\System32\tar.exe" -xf C:\Inputs\fixture.tar -C C:\Work
  if ($LASTEXITCODE -ne 0) { throw 'source fixture extraction failed' }
  New-Item -ItemType Directory C:\Tools\Code\data | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::ExtractToDirectory('C:\Inputs\extension.vsix','C:\Work')
  $project = 'C:\Work\Rune Ω'
  Move-Item -LiteralPath C:\Work\checkout -Destination $project
  $vm = 'C:\Work\extension\server\bin\runevm.exe'
  $server = 'C:\Work\extension\server\bin\runelsp.rbc'
  $env:PATH = "$env:SystemRoot\System32"
  $stage = 'project replay'
  & $vm C:\Work\project-replay.rbc $vm $server $project C:\Results\project.json *> C:\Results\project.log
  if ($LASTEXITCODE -ne 0) { throw 'project replay failed' }
  Set-Location -LiteralPath $project
  $stage = 'semantic protocol'
  & $vm C:\Work\semantic-tests.rbc $vm $server *> C:\Results\semantic.log
  if ($LASTEXITCODE -ne 0) { throw 'semantic suite failed' }
  if ((Get-Content C:\Results\semantic.log -Raw) -notmatch 'SUMMARY 45 tests, 45 passed, 0 failed') { throw 'missing semantic acceptance marker' }
  $stage = 'packaged library workflow'
  $env:RUNE_VSCODE_CHECKOUT = $project
  & $vm C:\Work\distribution-tests.rbc C:\Work\extension *> C:\Results\packaged.log
  if ($LASTEXITCODE -ne 0) { throw 'packaged suite failed' }
  if ((Get-Content C:\Results\packaged.log -Raw) -notmatch 'PASS vscode/packaged/regenerated-checkout-manifest') { throw 'missing manifest regeneration marker' }
  $stage = 'editor integration'
  $env:RUNE_VSCODE_PROJECT_ROOT = $project
  Remove-Item Env:RUNE_LSP_PROFILE -ErrorAction SilentlyContinue
  $projectUri = ([Uri]($project + '\')).AbsoluteUri.TrimEnd('/')
  @{folders=@(@{path=$project});settings=@{'runelsp.libraryRoot'=($projectUri+'/lib');'runelsp.targets'=@(@{name='rune';build=($projectUri+'/rune.build')});'runelsp.activeContext'='rune';'runelsp.trace.server'='verbose';'chat.disableAIFeatures'=$true}} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 C:\Work\rune.code-workspace
  $arguments = @('--disable-gpu','--disable-extensions','--disable-updates','--disable-telemetry','--skip-welcome','--skip-release-notes','--no-cached-data','--disable-workspace-trust','--user-data-dir=C:\Work\user','--extensions-dir=C:\Work\extensions','--extensionDevelopmentPath=C:\Work\extension','--extensionTestsPath=C:\Inputs\editor-suite.cjs','C:\Work\rune.code-workspace')
  $editor = Start-Process C:\Tools\Code\Code.exe -ArgumentList $arguments -PassThru -RedirectStandardOutput C:\Results\editor.log -RedirectStandardError C:\Results\editor-error.log
  if (-not $editor.WaitForExit(240000)) { Stop-Process -Id $editor.Id; throw 'editor integration exceeded 240 seconds' }
  $log = (Get-Content C:\Results\editor.log -Raw) + (Get-Content C:\Results\editor-error.log -Raw)
  if ($log -notmatch 'PASS vscode/editor/activation-hover-diagnostics-restart' -or $log -notmatch 'PASS vscode/editor/rune-project-hover-navigation-completion-edit-repair') { throw 'missing editor acceptance markers' }
  $status = 'PASS'
  @{status=$status;vscode=$codeVersion;stage=$stage;network='disabled';clipboard='disabled';sourcePath=$project} | ConvertTo-Json | Set-Content -Encoding UTF8 C:\Results\result.json
} catch {
  @{status=$status;vscode=$codeVersion;stage=$stage;message=$_.Exception.Message} | ConvertTo-Json | Set-Content -Encoding UTF8 C:\Results\result.json
  Write-Output $_
} finally {
  if (Test-Path C:\Work\user\logs) { Copy-Item C:\Work\user\logs C:\Results\editor-logs -Recurse -Force }
  if (Test-Path C:\Tools\Code\data\user-data\logs) { Copy-Item C:\Tools\Code\data\user-data\logs C:\Results\portable-editor-logs -Recurse -Force }
  Stop-Transcript
  @{nonce=$owner.nonce} | ConvertTo-Json | Set-Content -Encoding UTF8 C:\Results\complete.json
}
