# Arquitectura

## Componentes

### `ScreenshotManager`

- Consulta cada `0.4` segundos la carpeta predeterminada de capturas.
- Sólo considera PNG nuevos, regulares y no vacíos.
- Espera brevemente para permitir que macOS termine de escribir el archivo.
- Mueve el PNG a:

```text
~/Library/Application Support/ScreenshotShelf/Pending/
```

- Conserva hasta cinco miniaturas.
- Recupera archivos pendientes después de un reinicio moviéndolos a la carpeta
  predeterminada.

### `ThumbnailController`

Controla un `NSPanel` flotante por captura:

- Imagen con proporción fija.
- Controles que aparecen al hacer hover.
- Copiar al portapapeles.
- Guardar en el destino original.
- Descartar.
- Abrir el editor nativo y refrescar la miniatura cuando se aplican cambios.
- Drag and drop mediante `NSDraggingSource`.

La sesión de arrastre sólo comienza si:

- Es clic izquierdo.
- El botón izquierdo continúa presionado.
- El movimiento supera cinco puntos.
- El archivo pendiente existe.
- La ventana está visible.

Si el destino devuelve `.copy`, la miniatura se cierra y el archivo temporal se
elimina después de una espera breve.

### `EditorWindowController` y `EditorCanvas`

- Presentan una ventana AppKit propia; Preview no forma parte del flujo.
- Dibujan trazos, flechas, rectángulos, círculos y texto sobre el PNG.
- Mantienen historial en memoria para deshacer y rehacer.
- El recorte es no destructivo mientras la ventana permanece abierta.
- Al pulsar `Aplicar`, renderizan las anotaciones y el recorte a PNG y reemplazan
  atómicamente el archivo de `Pending`.

### Video

- `ScreenshotManager` observa también archivos `.mov` y `.mp4` creados por la interfaz
  nativa `⌘⇧5` de macOS.
- Antes de moverlos comprueba que su tamaño permanezca estable durante un
  segundo para no intervenir durante una grabación activa.
- `VideoThumbnailController` genera una vista previa, conserva el archivo en
  `Pending` y ofrece edición, guardado MP4, descarte y drag and drop.
- `VideoEditorWindowController` usa AVKit para reproducir y AVFoundation para
  recortar y exportar.
- La conversión GIF usa ImageIO, 12 FPS y un máximo de 1280 px.

### Grabador propio

- `ScreenRecordingCoordinator` registra `⌘⇧5` con Carbon.
- `CaptureOverlayController` dibuja el selector de región o pantalla.
- `SCStream` captura video y audio; `StreamWriter` los codifica como H.264/AAC.
- `RecordingHUDController` muestra tiempo y Detener sin aparecer en el video.
- Al finalizar, el MOV entra directamente al flujo de miniatura y edición.
- Requiere desactivar el `⌘⇧5` nativo y conceder Grabación de pantalla.

### `AppDelegate`

- Ejecuta la app como accesorio de barra de menú.
- Inicia y detiene `ScreenshotManager`.
- Expone `Buscar actualizaciones…`.
- Integra `SPUStandardUpdaterController`.

### Sparkle

- Lee `SUFeedURL` desde `Info.plist`.
- Compara `CFBundleVersion`.
- Verifica el archivo con `SUPublicEDKey`.
- Descarga el DMG publicado por GitHub Releases.
- Reemplaza la app instalada.

## Flujo de captura

```text
⌘⇧4 / ⌘⇧5
      ↓
macOS crea PNG o MOV
      ↓
ScreenshotManager lo detecta
      ↓
Mueve PNG a Pending
      ↓
ThumbnailController muestra NSPanel
      ↓
Editar / Copiar / Guardar / GIF / X / Drag and drop
      ↓
Cerrar panel y conservar o eliminar archivo
```

## Dependencias

- AppKit
- AVFoundation
- AVKit
- ImageIO
- Foundation
- Sparkle `2.9.2`

No depende de Hammerspoon para ejecutar la app.
