$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "..\scripts\catalogo.ps1"
$fixture = Join-Path $env:TEMP "elegir-modelo-catalogo-fixture-$PID.json"

@'
[
  {
    "id": "opencode/fast-free",
    "name": "Fast Free",
    "providerID": "opencode",
    "status": "active",
    "cost": { "input": 0, "output": 0, "cache": { "read": 0, "write": 0 } },
    "limit": { "context": 128000 },
    "capabilities": { "output": { "text": true }, "toolcall": true, "input": { "image": false, "pdf": false } },
    "variants": { "low": {}, "high": {} }
  },
  {
    "id": "ollama/local-code",
    "name": "Local Code",
    "providerID": "ollama",
    "status": "active",
    "cost": { "input": 0, "output": 0, "cache": { "read": 0, "write": 0 } },
    "limit": { "context": 32000 },
    "capabilities": { "output": { "text": true }, "toolcall": true, "input": { "image": false, "pdf": false } }
  },
  {
    "id": "google/gemini-image",
    "name": "Gemini Image",
    "providerID": "google",
    "status": "active",
    "cost": { "input": 1, "output": 2, "cache": { "read": 0, "write": 0 } },
    "limit": { "context": 64000 },
    "capabilities": { "output": { "text": true }, "toolcall": true, "input": { "image": true, "pdf": true } }
  },
  {
    "id": "google/no-tools",
    "name": "No Tools",
    "providerID": "google",
    "status": "active",
    "cost": { "input": 0, "output": 0, "cache": { "read": 0, "write": 0 } },
    "limit": { "context": 64000 },
    "capabilities": { "output": { "text": true }, "toolcall": false, "input": { "image": false, "pdf": false } }
  }
]
'@ | Set-Content -LiteralPath $fixture -Encoding UTF8

function Assert-True([bool]$condition, [string]$message) {
  if (-not $condition) { throw "TEST FAILED: $message" }
}

function Run-Catalogo([string[]]$arguments) {
  $result = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments
  Assert-True ($LASTEXITCODE -eq 0) "catalogo.ps1 termino con codigo $LASTEXITCODE"
  return ($result -join "`n")
}

$default = Run-Catalogo @("-InputFile", $fixture, "-SinCache")
Assert-True ($default -match "opencode") "el provider favorito no aparece"
Assert-True ($default -notmatch "ollama") "el provider secundario se filtro por defecto"
Assert-True ($default -notmatch "no-tools") "los modelos sin tools se filtraron"

$local = Run-Catalogo @("-InputFile", $fixture, "-SinCache", "-Provider", "local")
Assert-True ($local -match "ollama") "el alias local no resolvio ollama"

$image = Run-Catalogo @("-InputFile", $fixture, "-SinCache", "-Imagen")
Assert-True ($image -match "gemini-image") "el modo imagen no encontro el modelo multimodal"

$summary = Run-Catalogo @("-InputFile", $fixture, "-SinCache", "-Resumen")
Assert-True ($summary -match "4 modelos") "el resumen no conto el catalogo"

Remove-Item -LiteralPath $fixture -Force
Write-Output "OK: catalogo.Tests.ps1"
