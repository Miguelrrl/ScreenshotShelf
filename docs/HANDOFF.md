# Handoff

## Estado actual

- Repositorio: `https://github.com/Miguelrrl/ScreenshotShelf`
- Visibilidad: pública
- Versión en desarrollo: `0.4.4`
- Build en desarrollo: `17`
- Último tag publicado antes de este cambio: `v0.4.3`
- macOS mínimo: `13.0`
- Arquitecturas: Apple Silicon (`arm64`) e Intel (`x86_64`)
- Actualizaciones: Sparkle `2.9.2`
- Firma Apple: ad hoc; no hay Developer ID ni notarización
- Firma de actualizaciones: EdDSA de Sparkle
- Feed: `https://miguelrrl.github.io/ScreenshotShelf/appcast.xml`

## Estado funcional

- Observa la carpeta predeterminada de capturas de macOS.
- Desactiva únicamente la miniatura nativa de macOS.
- No vuelve a activar la miniatura nativa al cerrarse o actualizarse.
- Mueve capturas nuevas a almacenamiento temporal.
- Muestra una miniatura persistente en la pantalla del cursor.
- Permite copiar, guardar, descartar y hacer drag and drop.
- Incluye editor nativo con lápiz, flecha, rectángulo, círculo, texto y recorte.
- El editor permite elegir color y grosor, deshacer, rehacer y restablecer.
- El lienzo permanece centrado cuando es menor que el área visible.
- Las herramientas usan iconos SF Symbols con nombre accesible y tooltip.
- La esquina inferior derecha de la miniatura incluye un control para moverla.
- Las miniaturas reubicadas manualmente conservan su posición durante el apilado.
- El editor ofrece zoom visible, ajuste a ventana y zoom mediante trackpad.
- El texto insertado puede seleccionarse y moverse arrastrándolo.
- OCR local con Vision detecta texto de la captura y lo copia al portapapeles.
- Las miniaturas participan en todos los Spaces y acompañan al usuario al
  cambiar de escritorio.
- `Guardar como…` recuerda mediante `UserDefaults` la última carpeta elegida.
- Guardar crea el directorio si falta, usa copia como respaldo del movimiento,
  verifica el archivo final y oculta el panel antes de cerrarlo.
- Los errores de guardado se registran y se muestran sin perder la miniatura.
- Guardar y `Guardar como…` comparten la misma escritura verificada y ambos
  cierran la miniatura después del éxito.
- `Aplicar` reemplaza el archivo pendiente y actualiza la miniatura; `Cancelar`
  conserva la captura sin cambios.
- Permite elegir carpeta y nombre mediante el botón inferior `Guardar como…`.
- Configura `~/Pictures/ScreenshotShelf` como destino de capturas.
- Usa nombres `ScreenshotShelf <fecha> at <hora>.png` y etiqueta Finder.
- Cierra la miniatura después de un drop aceptado.
- Evita iniciar drag sin clic izquierdo y movimiento mínimo.
- Los paneles no acompañan todos los Spaces.
- Incluye icono de barra de menú y opción `Buscar actualizaciones…`.

## Configuración local relevante

El proyecto local original está en:

```text
/Users/MiguelRodriguez/Downloads/ScreenshotShelf-source
```

La app local construida está en:

```text
/Users/MiguelRodriguez/Downloads/ScreenshotShelf.app
```

El módulo anterior de Hammerspoon está desactivado en:

```text
~/.hammerspoon/init.lua
```

No vuelva a activar `require("screenshot-thumb")` mientras ScreenshotShelf esté
corriendo; ambos procesos competirían por el mismo PNG.

## Seguridad y secretos

- La clave pública EdDSA está en `Info.plist` bajo `SUPublicEDKey`.
- La clave privada está:
  - En el Llavero local, cuenta `ScreenshotShelf`.
  - En el secreto `SPARKLE_PRIVATE_KEY` del repositorio.
- La clave privada nunca debe incluirse en Git.
- La cuenta activa para este proyecto es `Miguelrrl`; conservarla autenticada
  hasta que el propietario confirme que terminó el trabajo.

## Próxima validación recomendada

Publicar `0.3.0` y probar la actualización real desde una Mac que tenga `0.2.4`
instalada en `/Applications`.

Validar:

1. `Buscar actualizaciones…` detecta `0.3.0`.
2. Sparkle descarga y verifica el DMG.
3. La app se reemplaza y reinicia.
4. Gatekeeper no impide el reemplazo ad hoc.
5. Todas las herramientas del editor producen el PNG esperado.
6. Captura, copiar, guardar y drag and drop siguen funcionando.
