# Catalogo

**Este archivo ya no se usa.** Se reemplazo por el script `scripts/catalogo.ps1`.

Motivo: el catalogo hardcodeado quedo desactualizado al momento de escribirse.
El provider `opencode-go` con 20 modelos que se habia asumido no existia; el
real es `opencode`, y hay 5 providers con 127 modelos en total.

El script descubre que providers hay en la maquina del usuario y lee precios
reales, asi que no hay nada que mantener aca.

```powershell
$cat = "<base-de-la-skill>\scripts\catalogo.ps1"

& $cat -Resumen       # stats por provider
& $cat                # todos
& $cat -SoloGratis
& $cat -Buscar flash
& $cat -Provider openai
& $cat -Refresh
```

Corre en Windows PowerShell 5.1 y en PowerShell 7. Ver SKILL.md para como
encontrar la ruta si la skill esta instalada en otro lado.

Cache: `~/.cache/opencode-modelos/`, 12h de validez.
