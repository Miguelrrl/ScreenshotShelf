# ScreenshotShelf — documentación

Este directorio contiene el contexto necesario para continuar el proyecto desde
otra sesión o computadora.

## Lectura recomendada

1. [HANDOFF.md](HANDOFF.md): estado actual y próximos pasos.
2. [ARCHITECTURE.md](ARCHITECTURE.md): componentes y flujo de una captura.
3. [DEVELOPMENT.md](DEVELOPMENT.md): entorno, compilación y pruebas.
4. [RELEASING.md](RELEASING.md): publicación y actualizaciones automáticas.
5. [DECISIONS.md](DECISIONS.md): decisiones técnicas y sus motivos.

## Archivos generados

- `appcast.xml`: feed público consumido por Sparkle.
- `ScreenshotShelf-<versión>.md`: notas de cada release.

No edite manualmente firmas dentro de `appcast.xml`. El workflow de release lo
regenera utilizando la clave EdDSA almacenada en GitHub Actions.
