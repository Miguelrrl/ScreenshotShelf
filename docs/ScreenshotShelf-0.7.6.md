# ScreenshotShelf 0.7.6

- La grabación de video no inicializa una pista de audio incompleta.
- Si el inicio falla, la región seleccionada vuelve a mostrarse automáticamente.
- Los errores de ScreenCaptureKit se escriben en el log con dominio y código.
- Los controles del selector y editor usan un diseño consistente de icono y
  texto; sólo el estado seleccionado y la acción primaria reciben color.
- Las grabaciones nuevas se producen directamente como MP4/H.264.
- El selector recuerda la última región y ofrece ocho handles para moverla y
  redimensionarla; la primera región aparece centrada.
- Durante la grabación, la región permanece clara con borde rojo y el exterior
  oscurecido. La capa no aparece dentro del video ni bloquea el mouse.
- `Esc` cierra el selector o cancela y descarta la grabación activa.
- Un clic sobre la miniatura abre el editor de video.
- El editor permite guardar el MP4 en la carpeta predeterminada o elegir otra
  ubicación con Guardar como.
- Guardar desde el editor respeta el recorte y elimina la miniatura pendiente
  después del éxito.
- El audio permanece desactivado en esta versión.

## Versión

- Marketing version: `0.7.6`
- Build: `29`
