<#
.SYNOPSIS
  Aplica, le ou desfaz o perfil de performance de GPU em notebooks Lenovo (LOQ/Legion) no Windows.

.DESCRIPTION
  -Detect   : imprime JSON com hardware, GPU e estado atual (nao altera nada).
  -Status   : imprime o estado atual (ou o ultimo estado lido como Admin).
  -Profile llm     (padrao): plano Equilibrado + SmartFanMode=3 (Performance) + Dynamic Boost + reset de clocks.
  -Profile restore : volta ao estado salvo antes da primeira aplicacao.
  Alterar exige Admin: o script se auto-eleva (UAC). A leitura WMI da Lenovo tambem exige Admin.
  Recusa maquinas fora de profiles/*.json, a menos que use -Force (os IDs WMI variam por modelo).
#>
param(
  [ValidateSet('llm', 'restore')][string]$Profile = 'llm',
  [switch]$Status,
  [switch]$Detect,
  [switch]$Force,
  [int]$DynamicBoostWatts = 15,
  [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$BalancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
$DynBoostId   = [uint32]0x02010300   # LENOVO_OTHER_METHOD feature ID (validado no 83UX; confirme em outros modelos)
$StateDir     = Join-Path $env:LOCALAPPDATA 'llm-boost'
$PrevFile     = Join-Path $StateDir 'previous-state.json'   # estado ORIGINAL, salvo uma vez
$LastFile     = Join-Path $StateDir 'last-state.json'       # ultimo estado lido como Admin
$ProfilesDir  = Join-Path (Split-Path $PSScriptRoot -Parent) 'profiles'
New-Item -ItemType Directory -Force $StateDir | Out-Null

function Test-Admin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-NvidiaSmi {
  $cmd = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $p = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
  if (Test-Path $p) { $p }
}

function Get-Machine {
  $p = Get-CimInstance Win32_ComputerSystemProduct
  $cs = Get-CimInstance Win32_ComputerSystem
  [ordered]@{
    Manufacturer = $cs.Manufacturer
    MachineType  = $p.Name       # ex.: 83UX
    Family       = $p.Version    # ex.: LOQ 15IRX11
    Bios         = (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
  }
}

function Get-Profiles {
  if (Test-Path $ProfilesDir) {
    Get-ChildItem $ProfilesDir -Filter *.json | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json }
  }
}

function Get-State {
  $fan = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_GAMEZONE_DATA -ErrorAction SilentlyContinue
  $oth = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_OTHER_METHOD -ErrorAction SilentlyContinue
  [ordered]@{
    SmartFanMode = if ($fan) { (Invoke-CimMethod -InputObject $fan -MethodName GetSmartFanMode).Data } else { $null }
    DynamicBoost = if ($oth) { (Invoke-CimMethod -InputObject $oth -MethodName GetFeatureValue -Arguments @{ IDs = $DynBoostId }).Value } else { $null }
    PowerPlan    = ((powercfg /getactivescheme) -replace '^.*:\s*([0-9a-f-]{36}).*$', '$1')
  }
}

function Save-Last($state) { $state | ConvertTo-Json | Set-Content $LastFile }

# ---------- somente leitura ----------
if ($Detect) {
  $smi = Get-NvidiaSmi
  $gpu = if ($smi) { (& $smi --query-gpu=name,driver_version,memory.total,power.limit,pstate --format=csv,noheader) } else { 'nvidia-smi.exe nao encontrado' }
  $wmi = [ordered]@{
    GamezoneClass = [bool](Get-CimClass -Namespace root\WMI -ClassName LENOVO_GAMEZONE_DATA -ErrorAction SilentlyContinue)
    OtherMethod   = [bool](Get-CimClass -Namespace root\WMI -ClassName LENOVO_OTHER_METHOD -ErrorAction SilentlyContinue)
  }
  $m = Get-Machine
  $known = @(Get-Profiles | Where-Object { $_.machineTypes -contains $m.MachineType } | ForEach-Object { $_.id })
  [ordered]@{
    Machine = $m; Gpu = $gpu; LenovoWmiClasses = $wmi; IsAdmin = (Test-Admin)
    MatchingProfiles = $known
    State = if (Test-Admin) { Get-State } else { 'WMI exige Admin: rode -Profile llm uma vez, ou -Status depois' }
  } | ConvertTo-Json -Depth 5
  return
}

if ($Status) {
  if (Test-Admin) { $s = Get-State; Save-Last $s; $s | ConvertTo-Json }
  elseif (Test-Path $LastFile) { Get-Content $LastFile; Write-Host '(estado em cache; a leitura WMI exige Admin)' }
  else { Write-Host 'Sem estado em cache. Rode -Profile llm (com UAC) uma vez.' }
  return
}

# ---------- altera: exige Admin ----------
if (-not (Test-Admin)) {
  if ($Elevated) { throw 'Elevacao falhou: o processo continua sem Administrador.' }
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated', '-Profile', $Profile, '-DynamicBoostWatts', $DynamicBoostWatts)
  if ($Force) { $a += '-Force' }
  $proc = Start-Process powershell.exe -Verb RunAs -ArgumentList $a -Wait -PassThru
  if (Test-Path $LastFile) { Get-Content $LastFile }
  exit $proc.ExitCode
}

# Guarda de seguranca: IDs WMI da Lenovo mudam por modelo.
$m = Get-Machine
$match = @(Get-Profiles | Where-Object { $_.machineTypes -contains $m.MachineType })
if (-not $match -and -not $Force) {
  throw "Maquina $($m.MachineType) ($($m.Family)) sem perfil em profiles/. Use -Detect e siga o AGENTS.md; -Force so apos validar os IDs WMI."
}

if ($Profile -eq 'restore') {
  if (-not (Test-Path $PrevFile)) { throw 'Nao ha estado anterior salvo. Nada a restaurar.' }
  $prev = Get-Content $PrevFile -Raw | ConvertFrom-Json
  powercfg /setactive $prev.PowerPlan
  $fan = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_GAMEZONE_DATA
  if ($null -ne $prev.SmartFanMode) { Invoke-CimMethod -InputObject $fan -MethodName SetSmartFanMode -Arguments @{ Data = [int32]$prev.SmartFanMode } | Out-Null }
  $oth = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_OTHER_METHOD
  if ($null -ne $prev.DynamicBoost) { Invoke-CimMethod -InputObject $oth -MethodName SetFeatureValue -Arguments @{ IDs = $DynBoostId; value = [uint32]$prev.DynamicBoost } | Out-Null }
  Remove-Item $PrevFile
  $s = Get-State; Save-Last $s; $s | ConvertTo-Json
  return
}

# Perfil llm. Salva o estado original uma unica vez (nunca sobrescreve com um estado ja boostado).
if (-not (Test-Path $PrevFile)) { Get-State | ConvertTo-Json | Set-Content $PrevFile }

powercfg /setactive $BalancedGuid   # Equilibrado preserva o orcamento dinamico (Intel IPF / NVIDIA Dynamic Boost)
$fan = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_GAMEZONE_DATA
Invoke-CimMethod -InputObject $fan -MethodName SetSmartFanMode -Arguments @{ Data = [int32]3 } | Out-Null
$oth = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_OTHER_METHOD
Invoke-CimMethod -InputObject $oth -MethodName SetFeatureValue -Arguments @{ IDs = $DynBoostId; value = [uint32]$DynamicBoostWatts } | Out-Null

$smi = Get-NvidiaSmi
if ($smi) { & $smi -rgc | Out-Null; & $smi -rmc | Out-Null } else { Write-Warning 'nvidia-smi.exe nao encontrado.' }

$s = Get-State; Save-Last $s; $s | ConvertTo-Json
