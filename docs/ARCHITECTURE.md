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
macOS crea PNG
      ↓
ScreenshotManager lo detecta
      ↓
Mueve PNG a Pending
      ↓
ThumbnailController muestra NSPanel
      ↓
Editar / Copiar / Guardar / X / Drag and drop
      ↓
Cerrar panel y conservar o eliminar archivo
```

## Dependencias

- AppKit
- Foundation
- Sparkle `2.9.2`

No depende de Hammerspoon para ejecutar la app.
