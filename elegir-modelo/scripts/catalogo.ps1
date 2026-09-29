<#
  catalogo.ps1 - Que modelos tiene ESTA instalacion, sin gastar tokens.

  Descubre solo los providers configurados en la maquina del usuario y
  lee precios reales. El parseo del JSON crudo (~127 modelos) ocurre en el
  shell, asi que al modelo le llega una linea por modelo, no el volcado.

  Uso (funciona en Windows PowerShell 5.1 y en PowerShell 7):
    & $cat                  # todos los providers (default)
    & $cat -Provider openai # solo uno
    & $cat -SoloGratis      # solo los free
    & $cat -Buscar kimi     # filtra por substring
    & $cat -Top 5           # los N mas baratos
    & $cat -Resumen         # stats por provider, sin detalle
     & $cat -Refresh         # ignora cache
     & $cat -SinCache        # no lee ni escribe cache
     & $cat -InputFile x.json # fixture local para pruebas, no llama al CLI

  donde $cat es la ruta a ESTE archivo (ver SKILL.md para como encontrarla).
  Requiere: el binario 'opencode' en el PATH. Cache en ~/.cache/opencode-modelos.
#>
param(
  [string]$Provider = "",
  [string]$Buscar = "",
  [switch]$SoloGratis,
  [switch]$Resumen,
  [switch]$Todos,
  [switch]$Imagen,
  [switch]$Providers,
  [switch]$Verificar,
  [switch]$Favoritos,
  [switch]$Refresh,
  [switch]$SinCache,
  [string]$InputFile = "",
  [int]$Top = 0,
  [int]$MaxHoras = 12
)

$ErrorActionPreference = "Stop"

# --- Configuracion (al inicio, antes de cualquier bloque) -------------------
# Providers con muchas variantes del mismo modelo base. Utiles, pero no son
# la primera recomendacion: se acceden con -Provider o -Todos.
# OJO: tiene que estar antes de los modos que la usan. Definida mas abajo,
# llegaba como $null por el orden de ejecucion.
$SECUNDARIO = @("nvidia","ollama","lmstudio","lm-studio","jan","llamacpp","localai")

# Home portable. $env:USERPROFILE no existe en Linux/macOS y $HOME no existe en
# CMD. Se resuelve una vez y se reutiliza en todo el script.
$home_ = if ($HOME) { $HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $null }
if (-not $home_) { throw "No se pudo determinar el home del usuario. Define HOME o USERPROFILE." }

# Separador nativo: backslash en Windows, slash en Unix. Join-Path lo resuelve solo.
$dir   = Join-Path $home_ ".cache/opencode-modelos"
$file  = Join-Path $dir "todos.json"
$stamp = Join-Path $dir "todos.stamp"

# --- Cache ------------------------------------------------------------------
function Read-Catalogo($path) {
  try {
    # OJO: @(pipeline) colapsa un array a un solo elemento. Asignar primero.
    $arr = Get-Content $path -Raw | ConvertFrom-Json
    return @($arr)
  } catch { return @() }
}

function Get-JsonObjects([string]$text) {
  # Extrae objetos JSON balanceando llaves. Es compatible con JSON multilinea,
  # objetos en una linea y llaves dentro de strings.
  $objects = @()
  $start = -1
  $depth = 0
  $quoted = $false
  $escaped = $false
  for ($i = 0; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($quoted) {
      if ($escaped) { $escaped = $false }
      elseif ($ch -eq '\\') { $escaped = $true }
      elseif ($ch -eq '"') { $quoted = $false }
      continue
    }
    if ($ch -eq '"') { $quoted = $true; continue }
    if ($ch -eq '{') {
      if ($depth -eq 0) { $start = $i }
      $depth++
    } elseif ($ch -eq '}' -and $depth -gt 0) {
      $depth--
      if ($depth -eq 0 -and $start -ge 0) {
        $objects += $text.Substring($start, $i - $start + 1)
        $start = -1
      }
    }
  }
  return @($objects)
}

function Get-SourceText {
  if ($InputFile) {
    if (-not (Test-Path -LiteralPath $InputFile)) {
      throw "Archivo de entrada no encontrado: $InputFile"
    }
    return Get-Content -LiteralPath $InputFile -Raw
  }
  # No usar -ErrorAction aqui: algunos wrappers de opencode escriben avisos en
  # stderr aunque el comando termine correctamente.
  return (& opencode models --verbose 2>$null | Out-String)
}

# --- Fuente: descubrir providers y parsear ---------------------------------
function Get-Catalogo {
  $raw = Get-SourceText
  if (-not $raw.Trim()) {
    if ($InputFile) { throw "El archivo de entrada no devolvio nada." }
    throw "'opencode models --verbose' no devolvio nada. Verifica la instalacion."
  }

  $modelos = @()
  $jsonItems = @()
  # Acepta tanto un array JSON de fixtures como los objetos que emite el CLI.
  try {
    $parsed = $raw.Trim() | ConvertFrom-Json
    if ($parsed -is [array]) { $jsonItems = @($parsed) }
    elseif ($parsed -is [pscustomobject] -and $parsed.id) { $jsonItems = @($parsed) }
  } catch {
    foreach ($json in (Get-JsonObjects $raw)) {
      try { $jsonItems += ($json | ConvertFrom-Json) } catch {}
    }
  }
  foreach ($o in $jsonItems) {
    try {
      if (-not $o.id) { continue }

      # Esquema real de 'capabilities' (verificado contra --verbose):
      #   { temperature, reasoning, attachment, toolcall,
      #     input:{text,audio,image,video,pdf}, output:{...}, interleaved }
      $cap = $o.capabilities
      if (-not $cap) { continue }
      # Para agenciar: genera texto + puede llamar tools.
      $esTexto   = $cap.output.text -eq $true
      $tieneTools = $cap.toolcall -eq $true
      $img       = $cap.input.image -eq $true
      $pdf       = $cap.input.pdf -eq $true

      # 'variants' viene como objeto {low:{},high:{}}, no como array.
      $vars = if ($o.variants) { ($o.variants.PSObject.Properties.Name -join ",") } else { "" }
      $modelos += [pscustomobject]@{
        id       = $o.id
        name     = $o.name
        provider = $o.providerID
        status   = $o.status
        in       = [double]($o.cost.input)
        out      = [double]($o.cost.output)
        cRead    = [double]($o.cost.cache.read)
        cWrite   = [double]($o.cost.cache.write)
        ctx      = [long]($o.limit.context)
        variants = $vars
        texto    = $esTexto
        tools    = $tieneTools
        imagen   = $img
        pdf      = $pdf
      }
    } catch {}
  }
  if ($modelos.Count -eq 0) { throw "No se parseo ningun modelo. El formato de opencode puede haber cambiado." }
  return @($modelos)
}

# --- Cache ------------------------------------------------------------------
$fresco = $false
$edad = 999
if (-not $Refresh -and -not $SinCache -and (Test-Path $file) -and (Test-Path $stamp)) {
  $edad = [math]::Round(
    (New-TimeSpan -Start (Get-Item $stamp).LastWriteTime -End (Get-Date)).TotalHours, 1)
  if ($edad -lt $MaxHoras) { $fresco = $true }
}

if ($fresco) {
  $modelos = Read-Catalogo $file
  if ($modelos.Count -eq 0) { $fresco = $false }
}

if ($fresco) {
  $origen = "cache ${edad}h"
} else {
  $modelos = Get-Catalogo
  if (-not $SinCache) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $modelos | ConvertTo-Json -Depth 4 | Set-Content $file -Encoding utf8
    Set-Content $stamp -Value ([DateTime]::Now.ToString("o")) -Encoding utf8
  }
  $origen = if ($InputFile) { "archivo de prueba" } else { "recien" }
}

$total = $modelos.Count

# --- Clasificacion de providers ---------------------------------------------
# PORTABLE: nada de esto hardcodea una maquina en particular. Los "favoritos" son los providers
# de modelos conocidos que cualquier persona tiene; los de variantes multiples (nvidia)
# dezenas de variantes y solo se ofrecen si el usuario los pide.
#
# $FAVORITOS  -> provider + familias de modelos, para detectar y ordenar.
# $SECUNDARIO -> providers que se excluyen del recomendado por defecto.
$FAMILIAS = @{
  "opencode" = @("space-bunny","big-pickle","longcat","ling","mimo","nemotron","muse-spark")
  "openai"   = @("gpt","chatgpt","o1","o3","o4")
  "google"   = @("gemini","gemma")
  "anthropic"= @("claude")
  "kimi"     = @("kimi","moonshot")
  "deepseek" = @("deepseek")
  "xai"      = @("grok")
  "zhipuai"  = @("glm","chatglm")
  "qwen"     = @("qwen","qwq")
  "alibaba"  = @("qwen","qwen3")
  "mistral"  = @("mistral","mixtral","codestral","devstral")
  "groq"     = @("llama","mixtral","gemma")
  "amazon"   = @("nova","titan")
  "cohere"   = @("command","aya")
}

function Get-Familia($modelo) {
  $id = $modelo.id.ToLower()
  foreach ($prov in $FAMILIAS.Keys) {
    foreach ($fam in $FAMILIAS[$prov]) {
      if ($id.Contains($fam)) { return $fam }
    }
  }
  return $null
}

function Get-TierProvider($prov) {
  if ($SECUNDARIO -contains $prov.ToLower()) { return "2" }
  # Un provider es favorito si alguna de sus familias esta en la tabla.
  foreach ($fam in $FAMILIAS.Keys) {
    if ($prov.ToLower() -eq $fam) { return "0" }
  }
  return "1"
}

# --- Favoritos: agrupar por familia de modelo -------------------------------
# "Que modelos puedo usar" = las familias conocidas, agrupadas y contadas.
if ($Favoritos) {
  # Nota: agrupar objetos y despues Contar sobre $null da vacio. Se proyecta a
  # filas planas {fam, ...} y se agrupa por el string.
  $agente = @($modelos | Where-Object { $_.texto -and $_.tools -and $_.status -eq "active" })
  $filas = @()
  foreach ($m in $agente) {
    $fam = Get-Familia $m
    if ($fam) {
      $filas += [pscustomobject]@{
        fam = $fam; id = $m.id; provider = $m.provider
        out = $m.out; ctx = $m.ctx; variantes = $m.variants
      }
    }
  }
  Write-Output "# $($filas.Count) modelos de familia conocida (de $total) :: $origen"
  foreach ($g in ($filas | Group-Object -Property fam | Sort-Object Name)) {
    $n = $g.Count
    $ms = $g.Group
    $gratis = @($ms | Where-Object { $_.out -le 0 }).Count
    $min = ($ms | Where-Object { $_.out -gt 0 } | Measure-Object out -Minimum).Minimum
    $provs = (($ms | ForEach-Object { $_.provider } | Sort-Object -Unique) -join ",")
    $precio = if ($gratis -eq $n) { "todo FREE" }
              elseif ($min) { "$gratis/$n free, desde " + ('{0:N2}' -f $min) + "/M" }
              else { "pagados" }
    "{0,-12} {1,2} modelos  {2,-24} [{3}]" -f $g.Name, $n, $precio, $provs
  }
  exit 0
}

# --- Verificar que providers estan realmente operativos --------------------
# Estar en la lista no implica funcionar. Ollama aparece siempre; si el server
# local esta caido, sus 5 modelos no sirven para nada.
if ($Verificar) {
  $listaProv = @($modelos.provider | Sort-Object -Unique)
  $nProv = $listaProv.Count
  Write-Output "# verificacion de $nProv providers :: $origen"
  function Get-AuthFile {
    $candidates = @()
    if ($env:XDG_DATA_HOME) {
      $candidates += Join-Path $env:XDG_DATA_HOME "opencode/auth.json"
    }
    $candidates += Join-Path $home_ ".local/share/opencode/auth.json"
    if ($env:APPDATA) {
      $candidates += Join-Path $env:APPDATA "opencode/auth.json"
    }
    foreach ($candidate in ($candidates | Select-Object -Unique) ) {
      if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
  }
  $authFile = Get-AuthFile
  $tieneAuth = @()
  if ($authFile) {
    try { $tieneAuth = @((Get-Content $authFile -Raw | ConvertFrom-Json).PSObject.Properties.Name) } catch {}
  }
  foreach ($prov in $listaProv) {
    $g = @($modelos | Where-Object { $_.provider -eq $prov })
    $ag = @($g | Where-Object { $_.texto -and $_.tools })
    $nota = ""
    $estado = "OK"
    if ($prov -eq "ollama") {
      try {
        # -UseBasicParsing solo existe en Windows PowerShell 5.1. En pwsh 7
        # disappeared (es el comportamiento por defecto), asi que ahi no se pasa.
        $ps5 = $PSVersionTable.PSVersion.Major -lt 6
        $url = "http://localhost:11434/api/tags"
        if ($ps5) { $null = Invoke-WebRequest $url -TimeoutSec 4 -UseBasicParsing }
        else      { $null = Invoke-WebRequest $url -TimeoutSec 4 }
        $estado = "OK (server vivo)"
      } catch {
        $estado = "CAIDO"; $nota = " <- server local apagado, NO usar"
      }
    } elseif ($prov -eq "opencode") {
      # La suscripcion de OpenCode no usa auth.json: viaja en la sesion.
      $estado = "OK (suscripcion)"
    } elseif ($tieneAuth.Count -gt 0 -and ($tieneAuth -notcontains $prov)) {
      $estado = "SIN CREDENCIAL"; $nota = " <- instalar con: opencode auth login"
    } elseif ($tieneAuth.Count -eq 0) {
      $estado = "NO VERIFICADO"; $nota = " <- no se encontro auth.json"
    }
    "{0,-10} {1,3} usables  {2}{3}" -f $prov, $ag.Count, $estado, $nota
  }
  exit 0
}

# --- Listar providers disponibles (para que la skill sepa que pedir) ---------
if ($Providers) {
  $listaProv = @($modelos.provider | Sort-Object -Unique)
  Write-Output "# $total modelos :: $origen :: providers disponibles:"
  foreach ($prov in $listaProv) {
    $g = @($modelos | Where-Object { $_.provider -eq $prov })
    $ag = @($g | Where-Object { $_.texto -and $_.tools })
    $gratis = @($ag | Where-Object { $_.out -le 0 }).Count
    "{0,-10} {1,3} usables ({2} free)" -f $prov, $ag.Count, $gratis
  }
  exit 0
}

# --- Resolver nombre colloquial -> providerID real --------------------------
# El usuario dice "opencode go" pero el build registra "opencode". Mapeamos
# lo que la gente dice a los IDs que el script YA discovered arriba.
# Solo alias -> id, y solo se aplican si ese id existe en la maquina.
# El nombre literal tiene prioridad (ver el bloque de resolucion mas abajo).
$ALIAS = @{
  "opencode go"         = "opencode"
  "opencodego"          = "opencode"
  "open code go"        = "opencode"
  "suscripcion"         = "opencode"
  "suscripcion opencode" = "opencode"
  "zen"                 = "opencode"
  "ollama"              = "ollama"
  "local"               = "ollama"
  "openai"              = "openai"
  "gpt"                 = "openai"
  "chatgpt"             = "openai"
  "google"              = "google"
  "gemini"              = "google"
  "nvidia"              = "nvidia"
  "nim"                 = "nvidia"
}

# --- Modo resumen: stats por provider, minimo tokens ------------------------
if ($Resumen) {
  $nprov = @($modelos.provider | Sort-Object -Unique).Count
  Write-Output "# $total modelos en $nprov providers :: $origen"
  $modelos | Group-Object provider | Sort-Object Count -Descending | ForEach-Object {
    $g = $_.Group
    $agente = @($g | Where-Object { $_.texto -and $_.tools })
    $gratis = @($agente | Where-Object { $_.out -le 0 }).Count
    $min = ($agente | Where-Object { $_.out -gt 0 } | Measure-Object out -Minimum).Minimum
    $n = $agente.Count
    $precio = if ($n -eq 0) { "sin modelos de agente" }
              elseif ($gratis -eq $n) { "$n agentes, todo FREE" }
              elseif ($min) { "$gratis/$n free, desde " + ('{0:N2}' -f $min) + "/M" }
              else { "$n agentes, pagados" }
    "{0,-10} {1,3} usable  {2}" -f $_.Name, $agente.Count, $precio
  }
  exit 0
}

# --- Filtros -----------------------------------------------------------------
# Regla: por defecto mostrar SOLO modelos usables para agenciar (texto + tools).
# -Buscar NO desactiva ese filtro: buscar "veo" debe devolver solo modelos de
# texto con tools, no el modelo de video que matchea el nombre.
# -Todos / -Imagen lo desactivan explicitamente.
if ($Imagen) {
  $modelos = @($modelos | Where-Object { $_.imagen })
} elseif (-not $Todos) {
  $modelos = @($modelos | Where-Object { $_.texto -and $_.tools })
}

# Por defecto se ocultan los providers con muchas variantes (nvidia, ollama...):
# son utiles pero no son la primera recomendacion. -Todos o -Provider los traen
# de vuelta. Un provider nombrado explicitamente siempre gana.
$pedido = $Provider
if ($pedido) {
  $pedido = $pedido.ToLower().Trim()
  if ($ALIAS.ContainsKey($pedido)) { $pedido = $ALIAS[$pedido] }
}
if (-not $Todos -and -not $Imagen -and -not $pedido) {
    $modelos = @($modelos | Where-Object { $SECUNDARIO -notcontains $_.provider.ToLower() })
}
if ($Provider) {
  $p = $Provider.ToLower().Trim()
  $resueltos = @($modelos.provider | Sort-Object -Unique)
  $original = $Provider

  # Orden de resolucion:
  #  1) el nombre literal, si existe de verdad. Tiene prioridad sobre el alias,
  #     asi si el provider se renombra a 'opencode-go' no lo pisamos con 'opencode'.
  if (-not ($resueltos -contains $p)) {
    #  2) alias coloquial, solo si su destino existe
    if ($ALIAS.ContainsKey($p) -and ($resueltos -contains $ALIAS[$p])) {
      $p = $ALIAS[$p]
    }
    # 3) prefijo, con un minimo de 3 letras para no adivinar.
    #    "go" -> google? No: 2 letras matchean mediaProviders. Sin alias ni
    #    prefijo suficiente, es un error explicito, no un filtro silencioso.
    elseif ($p.Length -ge 3) {
      $corta = @($resueltos | Where-Object {
        $_.ToLower().StartsWith($p) -or $p.StartsWith($_.ToLower())
      })
      if ($corta.Count -eq 1) { $p = $corta[0] }
      elseif ($corta.Count -gt 1) {
        Write-Output "# '$original' es ambiguo. Opciones: $($corta -join ', ')"
        exit 0
      } else {
        Write-Output "# provider '$original' no encontrado. Disponibles: $($resueltos -join ', ')"
        exit 0
      }
    } else {
      Write-Output "# '$original' es muy corto para adivinar. Disponibles: $($resueltos -join ', ')"
      exit 0
    }
  }
  $modelos = @($modelos | Where-Object { $_.provider.ToLower() -eq $p })
}
if ($SoloGratis) { $modelos = @($modelos | Where-Object { $_.out -le 0 }) }
if ($Buscar) {
  $b = $Buscar.ToLower()
  $modelos = @($modelos | Where-Object {
    $_.id.ToLower().Contains($b) -or $_.name.ToLower().Contains($b) -or $_.provider.ToLower().Contains($b)
  })
}

if ($modelos.Count -eq 0) {
  Write-Output "# sin coincidencias :: $origen"
  exit 0
}

# --- Emitir ------------------------------------------------------------------
function Tier($c) {
  if ($c -le 0) { return "FREE" }
  if ($c -lt 1)  { return "bajo" }
  if ($c -lt 5)  { return "medio" }
  return "CARO"
}

# Ordena por provider y luego por precio: el modelo decide rapido por provider.
$ordenados = @($modelos | Sort-Object provider, out, in)
if ($Top -gt 0) { $ordenados = @($ordenados | Select-Object -First $Top) }

$salida = foreach ($m in $ordenados) {
  # OJO: solo quitar el prefijo si es EXACTAMENTE el del provider. En nvidia los
  # ids llevan vendor ("z-ai/glm-5.3"), no provider: quitarlo produce "glm-5.3",
  # que no existe en la TUI como nvidia/glm-5.3.
  $id = $m.id
  if ($id.StartsWith($m.provider + "/")) { $id = $id.Substring($m.provider.Length + 1) }
  $precio = ('{0,6:N2}' -f $m.out) + "/M"
  $ctx    = if ($m.ctx -gt 0) { " " + [math]::Round($m.ctx / 1000) + "k" } else { "" }
  $cache  = if ($m.cRead -gt 0) { " cr" + ('{0:N3}' -f $m.cRead) } else { "" }
  $flag   = if ($m.status -ne "active") { " [" + $m.status + "]" } else { "" }
  $var    = if ($m.variants) { " {" + $m.variants + "}" } else { "" }
  "{0,-5} {1,-9} {2,-30} {3}{4}{5}{6}{7}" -f (Tier $m.out), $m.provider, $id, $precio, $ctx, $cache, $var, $flag
}

# OJO: la variable no puede llamarse $providers, choca con el switch -Providers
$provs = (($modelos.provider | Sort-Object -Unique) -join ",")
Write-Output "# $($modelos.Count) de $total modelos :: providers: $provs :: $origen"
$salida
Write-Output "# precio = out USD/M :: bajo<1 medio<5 CARO>=5 :: -Resumen para stats, -Refresh si dudas"
