---
name: elegir-modelo
description: Recomendacion de modelo por tipo de tarea. Invocacion explicita con /elegir-modelo <pregunta>.
disable-model-invocation: true
---

**Creada por los contribuidores de Elegir Modelo.** Skill open source para
seleccionar modelos de forma verificable y consciente del coste.

**Licencia:** MIT. Se puede usar, adaptar y redistribuir conservando el aviso
de copyright y la licencia.

**Feedback:** reporta errores de metodología, providers o formatos de OpenCode
en el repositorio público del proyecto cuando esté publicado.

# Elegir modelo

Objetivo: que el usuario elija bien **sin gastar de mas**. Se breve. Antes de recomendar, averigua la tarea real.

Esta es una skill open source y agnostica de la instalacion. No mantiene un catalogo
manual: descubre los modelos y precios disponibles en la maquina del usuario.

## Paso 1 - Clasifica la tarea y el provider

**Tarea:** encaja lo que pidio en una de estas. No hace falta anunciarlo.

| Intencion | Senales | Coste esperable |
|---|---|---|
| **Explorar** | "donde esta", "busca", "que archivos", "como esta armado" | gratis |
| **Borrador** | boilerplate, tests, docs, comentarios, tipos | minimo |
| **Auditar** | review, "esto esta bien?", seguridad, bugs | bajo |
| **Parche** | arreglar, corregir, bug concreto | bajo-medio |
| **Planificar** | "arma un plan", arquitectura, diseno | medio |
| **Ejecutar** | implementar, hacer la feature | medio |
| **Investigar** | documentacion, web, comparar libs, largo | medio |
| **Dificil** | no entiendo por que falla, solucion elusive | alto |
| **Estudio** | enseniarme, explicar, tutorial | bajo |

**Provider:** el usuario puede fijar uno ("pregunta + opencode go", "usando nvidia",
"con gemini"). Si lo nombro, filtro por ese provider. Si no, uso todos los que tenga.

Aliases que ya resuelve el script: `opencode go`, `suscripcion`, `zen` -> `opencode`;
`local` -> `ollama`; `gemini` -> `google`; `gpt` -> `openai`; `nim` -> `nvidia`.

Ojo: el usuario suele decir **"opencode go"** pero su build registra el provider
como **`opencode`**. El script resuelve solo. No le corrijas el nombre.

Si pide un provider que no tiene, o es ambiguo, el script lo dice con las
opciones disponibles. Ofrecelas en vez de adivinar.

## Paso 2 - Pregunta (max 2-3, en un solo turno)

Usa la herramienta `question`. **No adivines.** Pregunta solo lo que cambia la recomendacion:

- **Vas a iterar?** (muchos intentos cortos vs uno largo) -> decide nivel de razonamiento.
- **Cuanto contexto?** (archivos chicos vs repo entero) -> decide ventana y cache.
- **Presupuesto?** (probar gratis vs que funcione si o si) -> decide si ofreces paid o free.
- **Ya sabes con cual?** -> si si, solo confirma y listo.

Si la peticion ya es inequivoca, **no preguntes**: recomienda directo.

Si esta ambigua de verdad, delega el interrogatorio a la skill `grill-me` en vez de inventar tus propias preguntas.

## Paso 3 - Verifica y recomienda en texto corto

**Primero corré el Paso 5** (el script) para saber que modelos existen hoy. Si el
provider no aparece como `OK` en `-Verificar`, no lo recomiendes. Despues:

Formato fijo, maximo ~8 lineas. Nada de tablas largas ni explicaciones de por que funciona el modelo.

```
Para <tarea>: <modelo> (<razon corta>)
+ <pro>
- <contra>
Alternativa barata: <modelo free o barato> - sirve si <condicion>
```

Reglas de contenido:
- **1 principal + 1 alternativa barata.** Nunca mas de 2.
- Nombra el precio tal cual lo dio el script ("$0.50/M salida"), no de memoria.
- Menciona la **variante o nivel** solo si el script la mostro.
- Cierra con una sola pregunta: "¿Lo probamos o queres que ajuste?"

## Paso 4 - Cierra la accion

Si el usuario dice "dale", **no** ejecutes la tarea todavia. Confirma el modelo y espera su "go". Puede querer cambiar a algo mas barato.

Si dijo "usa X" explicitamente, respetalo sin recomendar.

---

## Paso 5 - Verifica antes de nombrar un modelo

OpenCode cambia precios, modelos y providers seguido. **Nunca nombres un modelo de memoria.**

El script descubre que providers tiene la maquina del usuario y lee los precios reales. Cachea 12h.

```powershell
# El path del script sale de la skill: <base-de-la-skill>/scripts/catalogo.ps1
$cat = "<base-de-la-skill>\scripts\catalogo.ps1"

& $cat -Resumen      # ~6 lineas: quantos y que tan baratos por provider
& $cat -Providers    # que providers hay, con cuantos usables
& $cat -Verificar    # que providers funcionan DE VERDAD ahora
& $cat               # todos los modelos usables, por provider y precio
& $cat -SoloGratis   # solo los free
& $cat -Buscar kimi  # filtra por nombre
& $cat -Provider X   # un provider (acepta alias: "opencode go")
& $cat -Top 5        # los N mas baratos
& $cat -Refresh      # fuerza refresco
```

**Como correrlo sin saber donde esta instalado.** La ruta de arriba depende de donde
se instalo la skill. Para encontrarla sola:

```powershell
$cat = (Get-ChildItem -Path @(
  "$HOME/.agents/skills", "$HOME/.config/opencode/skill", "$HOME/.claude/skills",
  "./.opencode/skill", "./.claude/skills"
) -Filter catalogo.ps1 -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
```

**Sobre el interprete:** el script corre en Windows PowerShell 5.1 y en PowerShell 7
(`pwsh`). La forma `& $cat` anda en ambos. Si preferis el modo `-File`, ajustalo al
interprete disponible: `pwsh -File ...` en PowerShell 7+, `powershell -File ...` en Windows.
No assumes que `pwsh` existe: en Windows 5.1 puro no esta y el comando falla.

Empieza por `-Resumen` (barato). Si el usuario fijo un provider, combine:
`-Provider "opencode go" -SoloGratis`. Baja al listado completo solo si vas a
proponer un modelo concreto.

**No corras el script sin flags para buscar un modelo:** lista los ~76 modelos
usables de todos los providers, y son ~1.900 tokens. Es el modo caro.
Elegi siempre uno de estos segun lo que necesites:

| Queres | Corre |
|---|---|
| Panorama general | `-Resumen` (~70 tok) |
| Que providers tenes | `-Providers` o `-Verificar` (~90 tok) |
| Solo un provider | `-Provider "opencode go"` |
| Los mas baratos | `-Top 5` (~120 tok) |
| Un nombre puntual | `-Buscar gpt -Top 3` (~100 tok) |
| Solo gratuitos | `-Provider X -SoloGratis -Top 5` |

**El filtro de providers queda en manos del usuario.** El listado por defecto
incluye todos, incluidos los que tienen decenas de variantes (nvidia) y los
locales. Si el usuario no pide uno especifico, preferi los providers que ya
conoces: `opencode` (suscripcion), `openai`, `google`. Menciona los demas solo
si los nombra o si el script dice que estan caidos.

Nota tecnica: el filtro por `-Provider` funciona, incluidos los aliases. Si aun
asi alguna vez devuelve un filtro vacio, corré `-Providers` para ver los IDs reales
y pasar el literal. No reconstruyas el script por eso.

**Estar en la lista no es lo mismo que funcionar.** Un provider caido (ej. Ollama
con el server local apagado) sigue listando sus modelos. Si el usuario reporta
un error de conexion, o antes de recomendar un provider raro, corré
`-Verificar` y **no ofrezcas modelos de un provider marcado CAIDO o SIN CREDENCIAL**.

El parseo del JSON crudo ocurre **en el shell**, asi que a vos te llega una linea por modelo. Eso mantiene barato el proceso.

**Reclame lo que diga el script, no lo que recuerdes.** Si el modelo que ibas a proponer no aparece, no lo propongas.

Si el script falla, decilo al usuario y ofrecé una alternativa que el script haya
verificado. No inventes precios ni supongas que un provider funciona.

### Pre-flight obligatorio antes de responder

Revisa mentalmente estas cuatro condiciones:

1. ¿Clasifique la tarea y respete el provider solicitado?
2. ¿Ejecute el comando minimo necesario del Paso 5?
3. ¿El modelo recomendado aparece en la salida y el provider esta operativo?
4. ¿La respuesta tiene como maximo un principal, una alternativa y una pregunta final?

Si alguna respuesta es no, corrige el proceso antes de enviar la recomendacion.

## Troubleshooting (instalacion en otra maquina)

El script solo depende de `opencode` en el PATH. Fallos tipicos:

| Sintoma | Causa | Arreglo |
|---|---|---|
| `no se reconoce como un cmdlet` para `pwsh` | PowerShell 7 no instalado (tipico en Windows 5.1) | Usar `& $cat`, o `powershell -File <ruta>` |
| `no se puede cargar el archivo... no está firmado` | ExecutionPolicy de Windows | `powershell -NoProfile -ExecutionPolicy Bypass -File <ruta>` |
| `No se pudo determinar el home` | Ni `HOME` ni `USERPROFILE` definidos | `set HOME=%USERPROFILE%` |
| `opencode models no devolvio nada` / `'opencode' no es un comando` | CLI no esta en el PATH | Instalar opencode, o abrir la terminal donde esta configurado |
| `No se parseo ningun modelo` | Cambió el formato de `opencode models --verbose` | El regex de `Get-Catalogo` (bloques JSON por linea) hay que ajustarlo |

Para diagnosticar: `& $cat -SinCache -Resumen` (fuerza re-lectura del CLI
y descarta la cache, que es lo primero que hay que descartar).

## Reglas de coste

1. **Nunca pagues por leer codigo.** Explorar y buscar va con modelo gratis, siempre.
2. **Subi nivel, no modelo.** X en `high` le gana a Y en `low` y cuesta 5 veces menos.
3. **Free primero.** Solo ofrece paid si la tarea lo justifica o el usuario lo pidio.
4. **El cache importa** en sesiones largas: releer contexto repetido es lo que mas duele.
5. **Si dudas entre dos, elige el barato** y di que se puede escalar.
6. **El cache del script dura 12h.** Si el usuario te dice que los precios cambiaron, corre con `-Refresh` una vez y segui.
