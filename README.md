# Elegir Modelo

Skill para OpenCode que recomienda el modelo más adecuado según la tarea, el
provider disponible, el contexto y el presupuesto. Descubre los modelos y
precios de la instalación local en lugar de depender de un catálogo fijo.

## Instalación / Installation

### Español

1. Copia la carpeta `elegir-modelo` en uno de estos directorios:
   - `~/.agents/skills/`
   - `~/.config/opencode/skill/`
   - `.opencode/skill/` dentro del proyecto
2. Verifica que el comando `opencode` esté disponible en el `PATH`.
3. Usa `/elegir-modelo <tu tarea>`.

La skill funciona con Windows PowerShell 5.1 y PowerShell 7. El script también
usa rutas portables para instalaciones que definan `HOME`, `USERPROFILE`,
`XDG_DATA_HOME` o `APPDATA`.

### English

1. Copy the `elegir-modelo` directory to one of:
   - `~/.agents/skills/`
   - `~/.config/opencode/skill/`
   - `.opencode/skill/` inside the project
2. Make sure the `opencode` command is available in `PATH`.
3. Run `/elegir-modelo <your task>`.

The skill supports Windows PowerShell 5.1 and PowerShell 7. The catalog script
uses portable locations based on `HOME`, `USERPROFILE`, `XDG_DATA_HOME`, and
`APPDATA`.

## Cómo funciona / How it works

- Clasifica la tarea: explorar, auditar, corregir, planificar, ejecutar,
  investigar, estudiar o resolver algo difícil.
- Respeta el provider solicitado y sus aliases.
- Consulta los modelos reales con `opencode models --verbose`.
- Lee precios, contexto, variantes y capacidades.
- Evita providers caídos o sin credenciales verificadas.
- Prioriza opciones gratuitas o económicas cuando son suficientes.

The skill never hardcodes a model catalog and does not invent prices. The
catalog is cached for 12 hours to reduce repeated CLI calls.

## Comandos útiles / Useful commands

```powershell
& $cat -Resumen
& $cat -Providers
& $cat -Verificar
& $cat -Provider "opencode go" -SoloGratis
& $cat -Buscar gemini -Top 3
& $cat -Refresh
```

## Tests

Desde la raíz del proyecto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\elegir-modelo\tests\catalogo.Tests.ps1
```

Las pruebas usan un fixture local y no necesitan credenciales ni llamadas a
un provider. / Tests use a local fixture and do not require credentials or
provider calls.

## Contribuir / Contributing

Consulta [CONTRIBUTING.md](CONTRIBUTING.md). Las mejoras deben mantener estas
reglas: no hardcodear modelos o precios, no exponer credenciales, conservar la
compatibilidad con PowerShell 5.1 y añadir una prueba para cada cambio de
comportamiento.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow. Changes
must not hardcode model prices, expose credentials, or drop PowerShell 5.1
compatibility; behavioural changes require tests.

## Licencia / License

MIT. See [LICENSE](LICENSE).
