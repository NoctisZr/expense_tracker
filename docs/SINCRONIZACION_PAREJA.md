# Sincronización de pareja (versión 2.0)

Cada persona conserva sus propios datos y su propia moneda. Lo que decide compartir se ve en la pestaña
**Pareja**, en solo lectura, sin mezclarse con sus gastos, presupuestos ni reportes.

## Qué se comparte
- **Por defecto, nada.** Cada tipo se activa por separado en *Pareja → Lo que comparto*: gastos, ingresos, metas, deudas
  (últimos 12 meses los gastos e ingresos).
- **Gastos en pareja** (se marcan al añadir un gasto): siempre se comparten; llevan total, quién pagó y la parte de cada quien.
- **Pagos** para saldar cuentas.
- Nunca se envían: cuentas, notas, etiquetas, presupuestos, créditos ni nada no listado arriba.

## Cómo funciona
1. **Sesión**: cada teléfono entra a Supabase como usuario anónimo (sin correo ni contraseña).
2. **Vincular**: una persona toca *Crear pareja* y obtiene un código de 12 caracteres (60 bits); la otra toca *Tengo un código*.
   El servidor solo guarda una huella SHA-256 del código y permite hasta 4 identidades por pareja (2 personas + reinstalaciones).
3. **Cifrado**: la clave AES-256-GCM se deriva del código (PBKDF2-HMAC-SHA256) y vive solo en los dos teléfonos.
   Cada dato se cifra en el teléfono; el servidor guarda texto ilegible (`payload` + `nonce`).
4. **Sincronización**: cada teléfono sube sus datos compartidos (solo lo que cambió) y baja lo nuevo de la otra persona.
   Cada quien solo puede modificar lo que escribió (política `items_update`). Los borrados son lógicos (`deleted`).
   Se sincroniza al abrir la app, al entrar a la pestaña (y cada 90 s mientras está abierta) y con el botón de sincronizar.
5. **Saldo**: se calcula en cada teléfono, convirtiendo a la moneda local de quien mira con sus propias tasas.

## Límites conocidos
- Si se borran los datos de la app, el teléfono entra como identidad nueva y se vuelve a unir solo con el código guardado;
  si la app se reinstala, hay que escribir el código otra vez y puede verse duplicado el historial antiguo propio.
- No es en tiempo real (no usa websockets): puede tardar hasta ~90 s en reflejarse.
- Quien tenga el código puede unirse a la pareja: hay que compartirlo solo con tu pareja.

## Configuración (ya hecha)
- Proyecto de Supabase con las tablas y políticas de `docs/supabase_schema.sql`, y *Anonymous sign-ins* activado.
- Secretos del repo: `SUPABASE_URL` y `SUPABASE_ANON_KEY` (clave pública `sb_publishable_…`). Sin ellos, la pestaña
  muestra que la función no está configurada.
