# Handoff

## Estado actual

- Repositorio: `https://github.com/Miguelrrl/ScreenshotShelf`
- Visibilidad: pública
- Versión en desarrollo: `0.7.6`
- Build en desarrollo: `29`
- Último tag publicado antes de este cambio: `v0.7.5`
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
- El menú incluye una ventana de Ajustes para elegir el destino predeterminado.
- El cierre automático es opcional y su tiempo se configura entre 1 y 3600
  segundos; al vencer, guarda la captura antes de cerrar la miniatura.
- Los destinos guardados se agregan a `seen` antes de cerrar el panel para que
  el monitor no vuelva a tratarlos como capturas nuevas.
- Ajustes permite copiar automáticamente cada captura nueva al portapapeles sin
  cerrar su miniatura.
- La copia automática puede ocultar por completo la miniatura; en ese modo la
  captura se guarda directamente en el destino predeterminado.
- El temporizador de guardado automático continúa aunque el cursor esté sobre
  la miniatura.
- Detecta grabaciones `.mov` o `.mp4` creadas por `⌘⇧5` cuando su tamaño permanece
  estable durante al menos un segundo.
- Muestra miniaturas de video persistentes con guardar, guardar como, editar,
  descartar, mover y drag and drop.
- El editor de video reproduce, navega y recorta el inicio y final.
- Guarda videos como MP4 y exporta GIF de hasta dos minutos a 12 FPS.
- Registra `⌘⇧5` mediante Carbon `RegisterEventHotKey`; no requiere permiso de
  Accesibilidad cuando el atajo nativo de Apple está desactivado.
- El selector propio permite elegir región o pantalla en el monitor del cursor.
- La grabación propia usa ScreenCaptureKit y produce MP4/H.264. El audio está
  desactivado en `0.7.6` hasta implementar su ciclo y permisos por separado.
- ScreenshotShelf se excluye del video para que el HUD no quede grabado.
- La selección recuerda la última región; si no existe, crea una región
  centrada que puede moverse y redimensionarse mediante ocho handles.
- Al grabar, la región continúa visible, el exterior permanece oscurecido y la
  barra/handles se ocultan. La capa no bloquea el mouse ni queda en el video.
- `Esc` cierra el selector o cancela y descarta una grabación activa.
- El editor usa una línea de tiempo única con fotogramas, manijas de recorte y
  cabezal de reproducción.
- Un clic sobre la miniatura abre el editor; un arrastre inicia drag and drop.
- El editor guarda el rango seleccionado en la carpeta predeterminada o en una
  ubicación elegida, aplica recortes en MP4 y exporta GIF.
- Las barras de selección y edición usan botones consistentes de icono y texto.
- Permite elegir carpeta y nombre mediante el botón inferior `Guardar como…`.
- Configura `~/Pictures/ScreenshotShelf` como destino de capturas.
- Usa nombres `ScreenshotShelf <fecha> at <hora>.png` y etiqueta Finder.
- Cierra la miniatura después de un drop aceptado.
- Evita iniciar drag sin clic izquierdo y movimiento mínimo.
- Los paneles acompañan todos los Spaces.
- Incluye icono de barra de menú y opción `Buscar actualizaciones…`.

## Configuración local relevante

El proyecto local original está en:

```text
/Users/MiguelRodriguez/Downloads/ScreenshotShelf-source
```

La app instalada y ejecutable está en:

```text
/Applications/ScreenshotShelf.app
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

Probar la actualización `0.7.6` desde otra Mac con `0.7.5` instalada en
`/Applications`.

Validar:

1. `Buscar actualizaciones…` detecta `0.7.6`.
2. Sparkle descarga y verifica el DMG.
3. La app se reemplaza y reinicia.
4. Gatekeeper no impide el reemplazo ad hoc.
5. `⌘⇧5`, selector, MP4, recorte, guardado y GIF funcionan.
6. Captura de imagen, copiar, guardar y drag and drop siguen funcionando.
