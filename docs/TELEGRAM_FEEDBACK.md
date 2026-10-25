# Reportes y sugerencias por Telegram

La app (Ajustes → Ayuda y novedades → **Reportar o sugerir**) envía el mensaje a un *Worker* gratuito
de Cloudflare, que lo reenvía a tu Telegram. El **token del bot vive solo en el Worker**, nunca dentro
de la app (si estuviera en el APK, cualquiera podría extraerlo y llenarte el chat).

## 1. Crear el bot
1. En Telegram abre **@BotFather** y escribe `/newbot`.
2. Elige un nombre y un usuario que termine en `bot`.
3. Copia el **token** (algo como `123456:ABC...`). Es secreto.

## 2. Obtener tu chat id
1. Abre tu bot y envíale cualquier mensaje ("hola").
2. En el navegador abre `https://api.telegram.org/bot<TU_TOKEN>/getUpdates`.
3. Busca `"chat":{"id":123456789` — ese número es tu **chat id**.

## 3. Publicar el Worker en Cloudflare
1. Crea una cuenta gratis en <https://dash.cloudflare.com>.
2. **Workers & Pages → Create → Create Worker**, ponle un nombre (p. ej. `expense-feedback`) y **Deploy**.
3. **Edit code**, borra lo que haya, pega el contenido de `tool/telegram_worker.js` y **Deploy**.
4. En **Settings → Variables and Secrets** agrega:
   - `TG_TOKEN` (tipo **Secret**): el token del paso 1.
   - `TG_CHAT_ID` (tipo Text): el número del paso 2.
   - `APP_KEY` (tipo Text): una clave cualquiera, p. ej. `k8s93hd72` (anótala).
5. *(Opcional, recomendado)* Límite de spam por IP: **Storage & Databases → KV → Create namespace**
   (`feedback-rl`) y en el Worker **Settings → Bindings → Add → KV namespace**, variable `RL`.
6. Copia la URL del Worker: `https://expense-feedback.<tu-usuario>.workers.dev`.

### Probarlo
```bash
curl -X POST "https://expense-feedback.<tu-usuario>.workers.dev" \
  -H "content-type: application/json" -H "X-App-Key: TU_APP_KEY" \
  -d '{"type":"idea","message":"Prueba desde curl","version":"1.5.0","build":10}'
```
Debe llegarte un mensaje a Telegram y responder `{"ok":true}`.

## 4. Conectar la app (variables de GitHub, no secretos)
En tu repositorio: **Settings → Secrets and variables → Actions → pestaña Variables → New repository variable**:
- `FEEDBACK_URL` = la URL del Worker.
- `FEEDBACK_APP_KEY` = el mismo valor de `APP_KEY`.

Haz push: el workflow las incluye al compilar. Sin estas variables, el botón abre el menú de compartir.

## Seguridad y privacidad
- `APP_KEY` solo frena el spam casual (va dentro de la app). El límite real está en el Worker (10 por hora por IP si activaste `RL`) y en la app (1 por minuto, 10 al día).
- Si alguien filtrara el token del bot: en @BotFather usa `/revoke` y actualiza `TG_TOKEN` en Cloudflare.
- La app **nunca envía gastos, ingresos ni montos**: solo el mensaje, el contacto opcional y los datos técnicos (que el usuario ve antes de enviar).
