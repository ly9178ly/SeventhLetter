param(
  [ValidateSet('Build', 'Test', 'Run')][string]$Task = 'Build',
  [string]$DevEcoHome = 'D:\huawei\DevEco Studio'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$nodePath = Join-Path $DevEcoHome 'tools\node\node.exe'
$hvigorPath = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.js'
$hdcPath = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (!(Test-Path -LiteralPath $nodePath)) { throw '请通过 -DevEcoHome 指定 DevEco Studio 安装目录。' }
$previousSdk = $env:DEVECO_SDK_HOME
$previousJava = $env:JAVA_HOME
Push-Location $projectRoot
try {
  $env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
  $env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
  $targetTask = if ($Task -eq 'Test') { 'test' } else { 'assembleHap' }
  & $nodePath $hvigorPath --mode module -p product=default -p module=entry@default $targetTask --no-daemon
  if ($LASTEXITCODE -ne 0) { throw "Hvigor 失败：$LASTEXITCODE" }
  if ($Task -eq 'Run') {
    $devices = & $hdcPath list targets
    if (!$devices -or $devices -match '\[Empty\]') { throw '请先在 DevEco Device Manager 启动 API 17 Phone 模拟器。' }
    $hap = Join-Path $projectRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
    & $hdcPath install $hap
    if ($LASTEXITCODE -ne 0) { throw '安装失败，请检查目标设备和本机签名配置。' }
    & $hdcPath shell aa start -a EntryAbility -b com.lvyang.seventhletter
  }
} finally {
  Pop-Location
  $env:DEVECO_SDK_HOME = $previousSdk
  $env:JAVA_HOME = $previousJava
}
