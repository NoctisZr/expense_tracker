# Pruebas de carga de la sincronización de pareja

**La idea:** que algo funcione con una sola persona (tú, en tu teléfono) no demuestra que aguante con
cientos. Es mejor encontrar el problema tú, en una prueba, que tus usuarios en producción.

## Reglas para no hacerte daño
1. **Usa un proyecto de Supabase SOLO para pruebas** (el plan gratis permite 2 proyectos). Nunca pruebes contra el de verdad.
2. En el proyecto de pruebas aplica el mismo `docs/supabase_schema.sql` y activa *Anonymous sign-ins*.
3. Los registros anónimos tienen un límite bajo por hora. En **Authentication → Rate Limits** súbelo (por ejemplo a 1000/hora)
   solo en el proyecto de pruebas; si no, la prueba se frenará con errores 429.
4. Empieza pequeño (5 usuarios, 1 minuto), luego sube. Una prueba grande contra el plan gratis puede gastar tu cuota.
5. Al terminar, limpia con `loadtest/cleanup.sql` (también solo en el proyecto de pruebas).

## Cómo correrla (Codespaces)
```bash
pip install locust
export SUPABASE_URL="https://TU-PROYECTO-DE-PRUEBAS.supabase.co"
export SUPABASE_KEY="sb_publishable_..."          # la clave pública del proyecto de pruebas
locust -f loadtest/locustfile.py --headless -u 10 -r 1 -t 2m --csv loadtest/resultados
```
`-u` = usuarios virtuales (cada uno = una pareja), `-r` = cuántos nuevos por segundo, `-t` = duración.
Alternativa con k6: ver la cabecera de `loadtest/k6_sync.js`.

## Qué mirar (la lección del video)
- **No te fíes del promedio.** Mira el **p95** (95 % de las peticiones fue más rápida que esto) y el **p99**:
  ahí se ve lo que sienten los usuarios con peor suerte.
- **Metas razonables:** `pull` p95 < 800 ms · `push` p95 < 1 s · errores < 1 % · **aislamiento: 0 fallos**.
- **Tipos de prueba:** *pico* (sube de golpe), *estrés* (sigue subiendo hasta que algo se rompe) y
  *resistencia* (carga estable durante mucho rato). Prueba las tres.
- Si el p95 se dispara: revisa el **Performance Advisor** de Supabase, los índices y los planes de consulta;
  si hay muchos 429/5xx, la app ya reintenta con espera creciente, pero conviene subir de plan o espaciar las consultas.

## Qué ya se hizo por escala
- Reglas de seguridad evaluadas una vez por consulta (`my_couple_ids()` + `(select auth.uid())`) en lugar de por cada fila.
- Índice `(couple_id, updated_at, id)` que coincide con la consulta de la app.
- La app consulta cada ~45 s **con azar** (para no sincronizar todos a la vez), pide miembros solo de vez en cuando,
  reintenta con espera creciente ante 429/5xx y espera más cuando hay errores seguidos.
