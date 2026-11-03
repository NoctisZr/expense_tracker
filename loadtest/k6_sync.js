// Prueba de carga de la sincronización de pareja con k6 (alternativa a Locust).
// Ejecutar SOLO contra un proyecto de PRUEBAS:
//   docker run --rm -i -e SUPABASE_URL=https://X.supabase.co -e SUPABASE_KEY=sb_publishable_... \
//     grafana/k6 run - < loadtest/k6_sync.js
// Tipos de prueba: pico (spike), estrés (sube hasta que algo se rompe) y resistencia (larga y estable).
import http from 'k6/http';
import { check, sleep } from 'k6';

const URL = __ENV.SUPABASE_URL;
const KEY = __ENV.SUPABASE_KEY;

export const options = {
  stages: [
    { duration: '1m', target: 10 },   // calentamiento
    { duration: '2m', target: 30 },   // carga normal
    { duration: '30s', target: 80 },  // PICO de tráfico
    { duration: '1m', target: 10 },   // recuperación
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{name:pull}': ['p(95)<800', 'p(99)<1500'],
    'http_req_duration{name:push}': ['p(95)<1000', 'p(99)<2000'],
    checks: ['rate>0.99'],
  },
};

let state = null; // una pareja por usuario virtual

function headers(token, extra) {
  return Object.assign(
    { apikey: KEY, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    extra || {}
  );
}

function signup() {
  for (let i = 0; i < 6; i++) {
    const r = http.post(`${URL}/auth/v1/signup`, JSON.stringify({ data: {} }), {
      headers: { apikey: KEY, 'Content-Type': 'application/json' },
      tags: { name: 'signup' },
    });
    if (r.status === 200) return { token: r.json('access_token'), uid: r.json('user.id') };
    sleep(Math.pow(2, i)); // límite de registros anónimos: espera y reintenta
  }
  throw new Error('No se pudo crear la sesión (sube el límite de registros anónimos del proyecto de pruebas)');
}

function rnd(n) {
  let s = '';
  for (let i = 0; i < n; i++) s += 'abcdefghijklmnopqrstuvwxyz0123456789'[Math.floor(Math.random() * 36)];
  return s;
}

function setup() {
  const a = signup();
  const b = signup();
  const invite = 'lt-' + rnd(32);
  const cid = http
    .post(`${URL}/rest/v1/rpc/create_couple`, JSON.stringify({ p_invite_hash: invite }), { headers: headers(a.token) })
    .json();
  http.post(`${URL}/rest/v1/rpc/join_couple`, JSON.stringify({ p_invite_hash: invite }), { headers: headers(b.token) });
  return { a, b, cid, n: 0 };
}

export default function () {
  if (!state) state = setup();

  // A sube 20 filas (el "subir" de la app)
  const rows = [];
  for (let i = 0; i < 20; i++) {
    state.n++;
    rows.push({
      couple_id: state.cid,
      id: `${state.a.uid}:expense:${state.n}`,
      kind: 'expense',
      payload: rnd(400),
      nonce: rnd(16),
      deleted: false,
    });
  }
  const push = http.post(`${URL}/rest/v1/shared_items?on_conflict=couple_id,id`, JSON.stringify(rows), {
    headers: headers(state.a.token, { Prefer: 'resolution=merge-duplicates,return=minimal' }),
    tags: { name: 'push' },
  });
  check(push, { 'push ok': (r) => r.status === 201 || r.status === 200 || r.status === 204 });

  // B descarga las novedades (el "bajar" de la app)
  const pull = http.get(
    `${URL}/rest/v1/shared_items?select=id,kind,payload,nonce,deleted,updated_at&couple_id=eq.${state.cid}` +
      `&author_id=neq.${state.b.uid}&order=updated_at.asc,id.asc&limit=500`,
    { headers: headers(state.b.token), tags: { name: 'pull' } }
  );
  check(pull, { 'pull ok': (r) => r.status === 200 });

  sleep(1 + Math.random() * 2);
}
