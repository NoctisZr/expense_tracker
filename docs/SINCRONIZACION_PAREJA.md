# Sincronización de pareja (versión 2.0) — diseño

Objetivo: dos personas, cada una con su app y sus gastos privados, comparten solo los gastos
marcados como «en pareja», ven los del otro y llevan la cuenta de quién le debe a quién.

## Ya hecho en la 1.8.0 (base local)
- `Expense.sharedTotal` (total de la cuenta) y `Expense.paidByCreator`; `amount` es la parte de quien lo anotó.
- `lib/utils/couple_balance.dart`: saldo entre dos personas (con pruebas). Ya contempla gastos
  anotados por la pareja (`byMe: false`).
- Sección «Gastos en pareja» en Planificación y bloque «Gasto en pareja» en el formulario.

## Qué hará la 2.0
1. **Cuenta anónima** de Supabase en cada teléfono (sin correo ni contraseña).
2. **Vincular**: una persona toca «Crear pareja» y obtiene un código de 8 caracteres; la otra lo escribe
   en «Unirme». El servidor guarda solo un hash del código y limita la pareja a 2 personas.
3. **Cifrado de extremo a extremo**: la clave AES-GCM se deriva del código de invitación (PBKDF2) y
   vive solo en los dos teléfonos. Supabase guarda texto cifrado (`payload` + `nonce`).
4. **Sincronización**: cada gasto en pareja se sube cifrado con `updated_at`; se baja lo nuevo desde
   la última marca; gana la edición más reciente; los borrados son lógicos (`deleted`).
   Funciona sin internet y se sincroniza al volver la conexión.
5. **Saldar cuentas**: un movimiento «liquidación» que lleva el saldo a 0.
6. **Pantalla Pareja**: gastos de ambos, quién pagó, saldo y filtro por mes.

## Lo que tienes que hacer tú (≈10 min)
1. Crea una cuenta gratis en supabase.com → **New project** (anota la contraseña de la base).
2. **Authentication → Sign In / Providers → Allow anonymous sign-ins** → activar.
3. **SQL Editor** → pega `docs/supabase_schema.sql` completo → **Run**.
4. **Project Settings → API**: copia **Project URL** y la clave **anon public**.
5. En GitHub: **Settings → Secrets and variables → Actions → New repository secret**:
   `SUPABASE_URL` y `SUPABASE_ANON_KEY` (la clave anon es pública por diseño; la seguridad la dan
   las políticas del SQL).
6. Avísame y armo la 2.0.

## Decisiones abiertas
- ¿Pareja de 2 personas únicamente (propuesto) o grupos de más gente?
- ¿Sincronizar solo los gastos «en pareja» (propuesto) o también ingresos y presupuestos compartidos?
