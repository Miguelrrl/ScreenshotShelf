# Handoff

## Estado actual

- Repositorio: `https://github.com/Miguelrrl/ScreenshotShelf`
- Visibilidad: pública
- Versión en desarrollo: `0.2.3`
- Build en desarrollo: `8`
- Último tag publicado antes de este cambio: `v0.2.2`
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
- Permite abrir la captura pendiente en Preview mediante el botón de lápiz.
- Permite elegir carpeta y nombre mediante el botón inferior `Guardar como…`.
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
- La cuenta personal de GitHub no debe quedar autenticada después del trabajo si
  se solicita acceso temporal.

## Próxima validación recomendada

Publicar `0.2.1` con un cambio pequeño y probar la actualización real desde una
Mac que tenga `0.2.0` instalada en `/Applications`.

Validar:

1. `Buscar actualizaciones…` detecta `0.2.1`.
2. Sparkle descarga y verifica el DMG.
3. La app se reemplaza y reinicia.
4. Gatekeeper no impide el reemplazo ad hoc.
5. Captura, copiar, guardar y drag and drop siguen funcionando.
