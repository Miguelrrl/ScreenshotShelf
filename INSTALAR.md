# ScreenshotShelf

Miniatura persistente para capturas de macOS con copiar, guardar, descartar y
drag and drop nativo.

## Instalación

1. Abra `ScreenshotShelf.dmg`.
2. Arrastre `ScreenshotShelf.app` a `Applications`.
3. Abra la app desde Aplicaciones.
4. Si macOS la bloquea por no estar notarizada:
   - Haga clic derecho sobre la app.
   - Seleccione **Abrir**.
   - Confirme **Abrir** una vez más.

La app aparecerá como un icono en la barra de menús.

## Si usaba el módulo de Hammerspoon

Comente o elimine esta línea de `~/.hammerspoon/init.lua`:

```lua
require("screenshot-thumb")
```

Después recargue Hammerspoon. El resto de su configuración seguirá funcionando.

## Uso

- Pase el cursor sobre la miniatura para mostrar los controles.
- **Copiar** copia la captura y cierra la miniatura.
- **Guardar** mueve la captura a la ubicación predeterminada de macOS.
- **X** descarta la captura.
- Arrastre la imagen hacia otra aplicación. Si el destino acepta el archivo, la
  miniatura desaparece después de completar el drop.

## Abrir automáticamente al iniciar sesión

Abra:

**Ajustes del Sistema → General → Elementos de inicio**

Agregue `ScreenshotShelf.app`.

## Desinstalar

1. Cierre ScreenshotShelf desde su icono en la barra de menús.
2. Elimine la app de Aplicaciones.
3. Reactive la miniatura nativa:

```bash
defaults write com.apple.screencapture show-thumbnail -bool true
killall SystemUIServer
```

## Compatibilidad

- macOS 13 o posterior.
- Binario universal para Apple Silicon e Intel.
- Firma ad hoc para uso personal; no está notarizada por Apple.
