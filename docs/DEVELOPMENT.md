# Desarrollo

## Requisitos

- macOS 13 o posterior
- Xcode y Command Line Tools
- Swift Package Manager
- GitHub CLI para publicar

## Compilación local

Desde la raíz:

```bash
./scripts/build-release.sh
```

Salida:

```text
dist/ScreenshotShelf.app
```

El script:

1. Compila `arm64`.
2. Compila `x86_64`.
3. Combina ambos binarios con `lipo`.
4. Añade el rpath hacia `Contents/Frameworks`.
5. Copia `Sparkle.framework`.
6. Integra `Info.plist` y `AppIcon.icns`.
7. Aplica firma ad hoc.
8. Verifica la firma.

## Crear DMG

```bash
./scripts/create-dmg.sh
```

Salida:

```text
dist/ScreenshotShelf.dmg
```

La presentación del DMG utiliza:

- `Resources/dmg/DS_Store`
- `Resources/dmg/dmg-background.png`
- Enlace simbólico a `/Applications`

## Ejecutar una build

Detenga cualquier instancia anterior y abra:

```bash
open dist/ScreenshotShelf.app
```

No ejecute simultáneamente el módulo `screenshot-thumb.lua` de Hammerspoon.

## Pruebas manuales mínimas

1. `⌘⇧4` muestra la cruz nativa.
2. La miniatura aparece en la pantalla del cursor.
3. Los controles aparecen con hover.
4. Copiar cierra la miniatura y conserva la imagen en el portapapeles.
5. Guardar devuelve el PNG a la carpeta predeterminada.
6. X elimina el PNG pendiente.
7. Drag and drop funciona hacia Finder y otra app.
8. Un drop cancelado conserva la miniatura.
9. Cambiar de Space sin captura no deja una imagen fantasma.
10. Reiniciar la app recupera archivos pendientes.

## Diagnóstico

Logs:

```bash
log show --last 10m --style compact --predicate 'process == "ScreenshotShelf"'
```

Verificar bundle:

```bash
codesign --verify --deep --strict --verbose=2 dist/ScreenshotShelf.app
file dist/ScreenshotShelf.app/Contents/MacOS/ScreenshotShelf
```
