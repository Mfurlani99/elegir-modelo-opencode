# Contribuir / Contributing

Gracias por mejorar Elegir Modelo.

## Reglas / Guidelines

- No agregues precios ni modelos hardcodeados al catálogo.
- No incluyas credenciales, tokens, rutas personales ni salidas privadas.
- Mantén compatibilidad con Windows PowerShell 5.1 y PowerShell 7 cuando sea
  posible.
- Cambios en el comportamiento del script deben incluir una prueba.
- Los mensajes que recibe el modelo deben seguir siendo breves y accionables.
- Documenta cualquier cambio relacionado con el formato de OpenCode.

Do not commit credentials, personal paths, private CLI output, or hardcoded
model prices. Behavioural changes require tests. Keep the recommendation output
short and preserve PowerShell 5.1 compatibility where possible.

## Flujo / Workflow

1. Crea una rama para el cambio.
2. Ejecuta `tests/catalogo.Tests.ps1`.
3. Describe el problema y el comportamiento esperado.
4. Abre un pull request pequeño y enfocado.

When changing parser behaviour, include a minimal fixture reproducing the
format. When changing recommendation rules, explain the cost or reliability
trade-off.
