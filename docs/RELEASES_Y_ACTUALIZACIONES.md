# Releases en GitHub y avisos de nueva versión

## Qué pasa en cada build
Tras compilar, el workflow publica un **release de GitHub** (descargable, marcado como "Latest"):
- Etiqueta `vX.Y.Z-N` (versión y número de build tomados de `pubspec.yaml`).
- Notas tomadas de la sección `## X.Y.Z` de `CHANGELOG.md`.
- Archivos `ExpenseTracker-X.Y.Z-arm64-v8a.apk` (el que casi todos instalan) y `…-armeabi-v7a.apk`.

## Cómo sacar una versión nueva (importante)
1. En `pubspec.yaml` sube el número, p. ej. `version: 1.5.1+11`. **El número después del "+" debe aumentar**:
   es lo que la app compara para saber si hay una versión nueva.
2. En `CHANGELOG.md` agrega una sección `## 1.5.1` con las novedades.
3. `git push`. Si repites el push sin cambiar el número, el release se actualiza pero la app no avisa.

## Cómo se enteran los usuarios
- **Dentro de la app:** al abrirla (como máximo una vez al día) busca el último release y muestra un
  aviso con las novedades y el botón **Descargar**. Pueden elegir *Más tarde* (3 días) u *Omitir esta versión*.
  También hay **Buscar actualizaciones** en Ajustes → Ayuda y novedades.
- **Push real, sin abrir la app:** canal de Telegram (abajo) o, para quien tenga cuenta de GitHub,
  *Watch → Custom → Releases* en el repositorio.

## Canal de Telegram con cada versión (opcional)
1. En Telegram crea un **canal** (público, con enlace, para compartirlo) y agrega tu bot como **administrador**.
2. El id del canal es `@nombre_del_canal` (si es público) o un número que empieza por `-100`.
3. En GitHub → **Settings → Secrets and variables → Actions → Secrets** crea:
   - `TELEGRAM_BOT_TOKEN`: el token de tu bot.
   - `TELEGRAM_CHANNEL_ID`: el id del canal.
4. Quien se una al canal recibe una notificación con cada versión nueva, con las novedades y el enlace.

## Requisitos y límites
- **El repositorio debe ser público** para que la app (y cualquiera) pueda consultar los releases.
  Con un repo privado la comprobación queda desactivada.
- Para que Android permita **actualizar encima** sin desinstalar, el APK debe estar firmado con
  tu clave propia (ver `SIGNING.md`).
- La instalación no es silenciosa: el usuario toca *Descargar*, abre el APK y confirma. La primera vez,
  Android le pedirá permitir "instalar apps desconocidas" al navegador.
