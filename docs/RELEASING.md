# Releases y actualizaciones

## Versiones

Antes de publicar, actualice en `Info.plist`:

- `CFBundleShortVersionString`: versión visible, por ejemplo `0.2.1`.
- `CFBundleVersion`: entero ascendente, por ejemplo `6`.

Sparkle compara principalmente `CFBundleVersion`; nunca reutilice ni reduzca ese
valor.

## Publicar

```bash
git add .
git commit -m "fix: descripción"
git push origin main

git tag -a v0.2.1 -m "ScreenshotShelf 0.2.1"
git push origin v0.2.1
```

El tag activa `.github/workflows/release.yml`.

## Workflow

El workflow:

1. Compila el bundle universal.
2. Genera el DMG.
3. Descarga el `appcast.xml` existente.
4. Firma la actualización con `SPARKLE_PRIVATE_KEY`.
5. Publica el DMG en GitHub Releases.
6. Actualiza `docs/appcast.xml`.
7. Publica las notas de versión.
8. GitHub Pages despliega el feed.

## URLs

- Releases:
  `https://github.com/Miguelrrl/ScreenshotShelf/releases`
- Feed:
  `https://miguelrrl.github.io/ScreenshotShelf/appcast.xml`

## Primera instalación

La versión `0.1.3` no contiene Sparkle. Debe reemplazarse manualmente por `0.2.0`
o posterior. Desde entonces, las actualizaciones pueden instalarse desde
`Buscar actualizaciones…`.

## Firma

La app usa firma ad hoc, por lo que Gatekeeper puede pedir autorización. Los
archivos de actualización sí llevan una firma EdDSA independiente.

No cambie simultáneamente la clave EdDSA y la identidad de firma de Apple en una
sola actualización futura; siga la documentación de rotación de Sparkle.
