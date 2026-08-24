param(
  [int]$Port = 8787
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
# Agora Web SDK richiede l'hostname "localhost", non 127.0.0.1.
$localUrl = "http://localhost:$Port/"
$loopbackUrl = "http://127.0.0.1:$Port/"
$prefix = $localUrl

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".js"   = "text/javascript; charset=utf-8"
  ".svg"  = "image/svg+xml"
  ".png"  = "image/png"
  ".ico"  = "image/x-icon"
  ".txt"  = "text/plain; charset=utf-8"
  ".md"   = "text/plain; charset=utf-8"
}

function Get-SafePath([string]$urlPath) {
  $relative = [Uri]::UnescapeDataString($urlPath.Split("?")[0].TrimStart("/"))
  if ([string]::IsNullOrWhiteSpace($relative)) { $relative = "index.html" }
  $combined = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
  $rootFull = [System.IO.Path]::GetFullPath($root)
  if (-not $combined.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }
  return $combined
}

function Get-ListeningPid([int]$ListenPort) {
  try {
    $conn = Get-NetTCPConnection -LocalPort $ListenPort -State Listen -ErrorAction Stop |
      Select-Object -First 1
    if ($conn) { return [int]$conn.OwningProcess }
  } catch {}
  $escaped = [regex]::Escape(":$ListenPort")
  foreach ($line in (netstat -ano)) {
    if ($line -match "$escaped\s+\S+\s+LISTENING\s+(\d+)\s*$") {
      return [int]$Matches[1]
    }
  }
  return $null
}

function Test-VisoreReady([string]$Url) {
  try {
    $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
    return $resp.StatusCode -ge 200 -and $resp.Content -match "Visore PC"
  } catch {
    return $false
  }
}

function Stop-OwnedListener([int]$ListenPort) {
  $procId = Get-ListeningPid $ListenPort
  if (-not $procId -or $procId -eq $PID) { return $false }
  $info = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
  if (-not $info) { return $false }
  $cmd = [string]$info.CommandLine
  $name = [string]$info.Name
  $owned = ($cmd -match "http\.server") -or
    ($cmd -match "avvia\.ps1") -or
    ($name -match "^(python|powershell|pwsh)")
  if (-not $owned) {
    Write-Host "Porta $ListenPort occupata da $name (PID $procId)."
    return $false
  }
  Write-Host "Chiudo il server precedente sulla porta $ListenPort (PID $procId)..."
  Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 600
  return $true
}

if (Test-VisoreReady $prefix) {
  Write-Host "Visore PC già in esecuzione: ${localUrl}index.html?v=19g"
  Start-Process "${localUrl}index.html?v=19g"
  exit 0
}

Stop-OwnedListener $Port | Out-Null

$python = @(
  (Get-Command python -ErrorAction SilentlyContinue),
  (Get-Command python3 -ErrorAction SilentlyContinue),
  (Get-Command py -ErrorAction SilentlyContinue)
) | Where-Object { $_ } | Select-Object -First 1

if ($python) {
  Write-Host "Avvio server Python (piu richieste insieme)..."
  if ($python.Name -eq "py.exe") {
    & $python.Source -3 "$PSScriptRoot\server.py" $Port
  } else {
    & $python.Source "$PSScriptRoot\server.py" $Port
  }
  exit $LASTEXITCODE
}

Write-Host "Python non trovato, uso il server PowerShell."

$listener = $null
$started = $false
for ($attempt = 1; $attempt -le 3 -and -not $started; $attempt++) {
  $listener = [System.Net.HttpListener]::new()
  $listener.Prefixes.Add($localUrl)
  try { $listener.Prefixes.Add($loopbackUrl) } catch {}
  try {
    $listener.Start()
    $started = $true
  } catch {
    try { $listener.Close() } catch {}
    $listener = $null
    if ($attempt -lt 3) {
      Stop-OwnedListener $Port | Out-Null
      Start-Sleep -Milliseconds 400
      continue
    }
    if (Test-VisoreReady $prefix) {
      Write-Host "Visore PC già in esecuzione: $prefix"
      Start-Process $prefix
      exit 0
    }
    $holder = Get-ListeningPid $Port
    Write-Host "Impossibile aprire $prefix"
    Write-Host $_.Exception.Message
    if ($holder) {
      Write-Host "Processo sulla porta ${Port}: PID $holder"
    }
    Write-Host "Chiudi l'altro programma sulla porta $Port e riprova."
    exit 1
  }
}

Write-Host "Visore PC: ${localUrl}index.html?v=19g"
Write-Host "Lascia questa finestra aperta. Ctrl+C per chiudere."
Start-Process "${localUrl}index.html?v=19g"

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $path = Get-SafePath $context.Request.Url.AbsolutePath
    $response = $context.Response
    if ($null -eq $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
      $response.StatusCode = 404
      $bytes = [Text.Encoding]::UTF8.GetBytes("Not found")
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.Close()
      continue
    }
    $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    $response.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" })
    $response.Headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.Close()
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
