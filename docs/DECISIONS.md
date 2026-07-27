# Decisiones técnicas

## App nativa en lugar de Hammerspoon

Hammerspoon permitió validar rápidamente la miniatura, pero `hs.canvas` no puede
ser origen de drag and drop nativo. AppKit sí ofrece `NSDraggingSource`.

## Observar archivos en lugar de reemplazar Screenshot.app

La app conserva los atajos y la interfaz nativa de macOS. Sólo administra el PNG
después de que macOS lo crea.

## Almacenamiento temporal

El PNG se mueve a `Application Support` para que:

- Guardar sea una decisión explícita.
- Descartar elimine realmente la captura.
- Copiar no deje un archivo no deseado.
- Drag and drop pueda entregar una URL de archivo real.

## Paneles separados por Space

Se retiró `canJoinAllSpaces` después de detectar sesiones de arrastre fantasma al
cambiar de escritorio. Cada panel permanece en el Space donde apareció.

## Sparkle sin Developer ID

Se eligió Sparkle con EdDSA y firma ad hoc para habilitar actualizaciones sin
pagar todavía Apple Developer.

Consecuencias:

- Gatekeeper puede solicitar autorización.
- La seguridad de la actualización depende de la clave EdDSA.
- En el futuro puede añadirse Developer ID y notarización sin reemplazar
  Sparkle.

## GitHub como infraestructura

- Código: repositorio público.
- Binarios: GitHub Releases.
- Feed: GitHub Pages.
- Automatización: GitHub Actions.

Esto evita mantener servidores propios.
