// Cloudflare Worker: recibe los reportes de la app y los reenvía a tu Telegram.
//
// Variables que debes definir en Cloudflare (Settings -> Variables and Secrets):
//   TG_TOKEN    (Secret)   token del bot que te dio @BotFather
//   TG_CHAT_ID  (Text)     tu chat id (o el id de un grupo/canal privado)
//   APP_KEY     (Text)     una clave cualquiera; la app la envía en la cabecera X-App-Key
//   RL          (opcional) un KV namespace para limitar el spam por IP (10 por hora)
//
// El token del bot NUNCA va dentro de la app: solo vive aquí.

const TYPES = {
  bug: '🐞 Error',
  idea: '💡 Sugerencia',
  question: '❓ Pregunta',
};
const MAX_BODY = 6000;
const MAX_MESSAGE = 1500;
const MAX_PER_HOUR = 10;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// Quita caracteres de control y recorta; devuelve '' si no es texto.
function clean(value, max) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '').trim().slice(0, max);
}

// Solo se aceptan datos técnicos simples (texto, número, booleano).
function cleanTech(tech) {
  if (!tech || typeof tech !== 'object' || Array.isArray(tech)) return {};
  const out = {};
  let count = 0;
  for (const [key, value] of Object.entries(tech)) {
    if (count >= 12) break;
    const k = clean(key, 24);
    if (!k) continue;
    if (typeof value === 'string') out[k] = clean(value, 60);
    else if (typeof value === 'number' && Number.isFinite(value)) out[k] = value;
    else if (typeof value === 'boolean') out[k] = value;
    else continue;
    count++;
  }
  return out;
}

export function buildText(data) {
  const type = TYPES[data.type];
  const lines = [`${type} · v${data.version || '?'} (build ${data.build || '?'})`, '', data.message];
  if (data.contact) lines.push('', `Contacto: ${data.contact}`);
  const techEntries = Object.entries(data.tech || {});
  if (techEntries.length) {
    lines.push('', '— Datos técnicos —');
    lines.push(techEntries.map(([k, v]) => `${k}: ${v}`).join(' · '));
  }
  return lines.join('\n').slice(0, 4000);
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);
    if (!env.TG_TOKEN || !env.TG_CHAT_ID) return json({ ok: false, error: 'not_configured' }, 500);
    if (env.APP_KEY && request.headers.get('X-App-Key') !== env.APP_KEY) {
      return json({ ok: false, error: 'unauthorized' }, 401);
    }

    const raw = await request.text();
    if (raw.length > MAX_BODY) return json({ ok: false, error: 'too_large' }, 413);

    let input;
    try {
      input = JSON.parse(raw);
    } catch (_) {
      return json({ ok: false, error: 'bad_json' }, 400);
    }
    if (!input || typeof input !== 'object') return json({ ok: false, error: 'bad_json' }, 400);

    const data = {
      type: clean(input.type, 12),
      message: clean(input.message, MAX_MESSAGE),
      contact: clean(input.contact, 120),
      version: clean(String(input.version ?? ''), 20),
      build: clean(String(input.build ?? ''), 10),
      tech: cleanTech(input.tech),
    };
    if (!TYPES[data.type]) return json({ ok: false, error: 'bad_type' }, 400);
    if (data.message.length < 5) return json({ ok: false, error: 'message_too_short' }, 400);

    // Límite por IP (si hay un KV llamado RL enlazado).
    if (env.RL) {
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const key = `rl:${ip}`;
      const count = parseInt((await env.RL.get(key)) || '0', 10);
      if (count >= MAX_PER_HOUR) return json({ ok: false, error: 'rate_limited' }, 429);
      await env.RL.put(key, String(count + 1), { expirationTtl: 3600 });
    }

    const response = await fetch(`https://api.telegram.org/bot${env.TG_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      // Sin parse_mode: el texto del usuario nunca se interpreta como formato.
      body: JSON.stringify({
        chat_id: env.TG_CHAT_ID,
        text: buildText(data),
        disable_web_page_preview: true,
      }),
    });
    if (!response.ok) return json({ ok: false, error: 'telegram_failed' }, 502);
    return json({ ok: true });
  },
};
