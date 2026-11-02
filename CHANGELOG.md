# Changelog

## 2.1.0
- **Interfaz más limpia y fácil de usar**:
  - Pestañas grandes con icono (Resumen, Movimientos, Planes, Pareja): ya no se cortan las palabras.
  - **Resumen**: primero tu balance, un botón grande de «Añadir gasto» y tus cuentas; el análisis, la vista
    anual, las categorías y la moneda local pasan a «Más detalles», que se abre cuando lo necesitas.
  - **Ajustes** ordenados en 5 secciones que se abren y cierran: Lo básico, Avisos y seguridad,
    Mi dinero, Mis datos y Avanzado (mods y fondo personalizado).
- **Al instalar** se pregunta cómo prefieres usarla: **Sencilla** (letra grande y solo lo básico) o **Completa**.
- Selector de color: vuelve a tener el campo de código hex en el editor de mods, y «Color personalizado» de
  Ajustes usa el mismo selector.

## 2.0.0
- **Pareja** (nueva pestaña): finanzas en pareja con sincronización entre dos teléfonos. Cada quien
  conserva sus propios gastos y su propia moneda; lo de tu pareja se ve en un apartado aparte,
  en solo lectura, y nunca se mezcla con tus datos, presupuestos ni reportes.
- **Tú decides qué compartes**: gastos, ingresos, metas y deudas, cada uno con su interruptor
  (por defecto no se comparte nada). Los «Gastos en pareja» (para dividir) siempre se comparten.
- **Saldo y pagos**: la app calcula quién le debe a quién (convirtiendo entre monedas a tu moneda
  local) y permite registrar pagos para saldar cuentas.
- **Tutorial** al activar la función, y se puede volver a ver cuando quieras.
- **Vincular**: una persona crea la pareja y comparte un código de 12 caracteres; la otra lo escribe.
- **Privacidad**: todo viaja cifrado de extremo a extremo (AES-256-GCM); el servidor solo guarda
  texto ilegible. Sin cuentas ni contraseñas. Funciona sin internet y sincroniza al volver.
- Requiere los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY` en el repositorio (ver docs/SINCRONIZACION_PAREJA.md).

## 1.9.2
- **Primer inicio automático**: en una instalación nueva la app deduce tu país por la IP (una sola
  consulta, solo se guarda el código de país; si no hay internet usa la región del teléfono) y deja
  como moneda local la de ese país. Esa moneda es la que usan por defecto el presupuesto y el conversor.
- **Idioma**: se usa el idioma del teléfono; si no es español, inglés o portugués, se usa el del país detectado.
- **Cada moneda con su idioma**: al cambiar la moneda local en el Resumen, si esa moneda suele usarse
  con otro idioma de la app, te ofrece cambiarlo (nunca lo cambia sola).
- Quien actualiza desde una versión anterior (ya tiene datos) no ve ningún cambio.

## 1.9.1
- **Colores bajo tu control otra vez**: vuelven los colores originales (la paleta azul marino quedó
  atrás) y se mantiene el nombre, el icono y la cabecera de Nuvio.
- Nuevo **«Color personalizado»**: elige cualquier color con tono, intensidad y brillo.
- Nuevo control **«Color en los fondos»**: de 0 % (fondos neutros) a 100 %, los fondos y las tarjetas
  toman el tono de tu color de acento, así que cambiar el color sí transforma toda la app.
- **«Restablecer colores»** vuelve al acento original con fondos neutros.
- Los mods siguen mandando sobre los colores cuando hay uno activo.

## 1.9.0
- **Presupuesto semanal** (Planificación): límite por semana (lunes a domingo) con cuánto llevas,
  cuánto te queda, cuánto puedes gastar por día y un aviso si vas más rápido de lo previsto.
- **Sobres** (Planificación): reparte los ingresos del mes en sobres (por defecto 50/30/20), asigna
  categorías a cada uno y mira cuánto queda; los sobres sin categorías son reservas (ahorro).
- **Reporte PDF**: ahora incluye la comparativa con el mes anterior (variación de gastos e ingresos y
  las categorías que más subieron y bajaron), la evolución de los últimos 6 meses e ingresos vs gastos.
- **Primeros pasos**: lista que se completa sola (cuenta, primer gasto, ingreso, presupuesto).
- Arreglo: la categoría larga («Comisión Bancaria») ya no se corta en la lista de gastos.
- Los respaldos incluyen sobres y presupuesto semanal.

## 1.8.0
- **Gastos en pareja** (en «Añadir gasto» → interruptor «Gasto en pareja»): guardas el total de la
  cuenta, quién pagó y tu parte (0–100 %). Solo tu parte cuenta como gasto tuyo. En Planificación
  → «Gastos en pareja» ves quién le debe a quién. Es la base de la sincronización de la 2.0.
- **Créditos**: nuevos modos de registro — A (todo hoy en un solo gasto) y C (la compra hoy y las cuotas
  solo con su interés) además del B (cada cuota como gasto). Atajo «Pagar a crédito en cuotas» en
  el formulario de gasto, con el monto ya escrito.
- **Regla de ahorro** (Planificación): elige qué % de tus ingresos del mes quieres ahorrar y ve cuánto
  te queda por gastar sin romper la meta.
- **Modo simple** (Ajustes): letra más grande y solo lo básico (sin Planificación ni análisis).
- Los respaldos incluyen los gastos en pareja y los modos de crédito.

## 1.7.0
- **Gasto desde un SMS**: pega el mensaje de tu banco (botón del SMS junto a «Escanear factura») y
  la app lee el importe, el comercio, la fecha, la moneda y si es gasto o ingreso; lo revisas y guardas.
- **Exportar a Excel (.xlsx)** desde Ajustes, además del CSV. Se abre en Excel, Google Sheets y LibreOffice.
- **Créditos**: comisión inicial y seguro también como porcentaje (el seguro como % mensual del saldo).
- **Avisos de cuotas**: te avisa el día antes de que venza cada cuota de tus compras a crédito.

## 1.6.0
- **Nuevo nombre: Peculio** (antes «Expense Tracker»). Cambia el nombre que se ve bajo el icono y
  dentro de la app; el identificador interno no cambia, así que se instala encima de tus datos.
- **Créditos y cuotas** (Planificación → Créditos y cuotas): registra compras a crédito en cuotas con
  tasa mensual, TEA o TNA, comisión inicial, seguro o cargos por cuota y meses de gracia. Cada cuota
  se registra sola como gasto en su fecha de vencimiento (la comisión inicial se suma a la primera).
- **Calculadora de intereses**: cuota, total a pagar, intereses, costo efectivo anual (TCEA), tabla de
  amortización, comparador de plazos (3/6/12/18/24/36), contado vs cuotas y simulación de pago adelantado.
- **Intereses ajustables**: cambia la tasa o el plazo y solo se recalculan las cuotas futuras; anota lo
  que el banco realmente cobró en cada cuota y ve la diferencia con el cálculo.
- Cuentas: nuevo tipo **Tarjeta de crédito** con límite y disponible.
- Respaldos: formato 6 (incluye los créditos). Los respaldos antiguos se siguen importando.
- Cada build publica **dos APK por separado** (arm64-v8a y armeabi-v7a) y usa acciones de GitHub
  actualizadas a Node 24.

## 1.5.1
- Subida de versión manual (sin cambios de código).
## 1.5.0
- Botón **Reportar o sugerir** (Ajustes → Ayuda y novedades): el mensaje llega al desarrollador por
  Telegram (a través de un Worker de Cloudflare; el token del bot no va dentro de la app). Incluye
  vista previa de lo que se envía, datos técnicos opcionales, límites anti-spam y cola sin conexión.
- **Releases automáticos en GitHub** tras cada build: etiqueta `vX.Y.Z-N`, notas tomadas de este
  CHANGELOG, APK renombrados y marcado como "último release".
- **Aviso de nueva versión dentro de la app** (una vez al día y a demanda): ver novedades, descargar,
  más tarde u omitir esa versión.
- Aviso opcional en un canal de Telegram con cada versión nueva.

## 1.4.2
- APK más liviano: se compila un APK por arquitectura (`--split-per-abi`) y sin símbolos de
  depuración (`--split-debug-info`). El APK "gordo" repetía el motor de Flutter y ML Kit tres
  veces (~100 MB). Se publican `app-arm64-v8a-release.apk` (casi todos los teléfonos) y
  `app-armeabi-v7a-release.apk` (teléfonos muy antiguos de 32 bits).
- El resumen de la ejecución muestra el tamaño de cada APK.

## 1.4.1
- Corrección probable del build "lite": reglas de R8 (proguard-rules.pro) para ML Kit (OCR) y para
  las notificaciones; sin ellas, el build release de ML Kit suele fallar con "Missing class".
- tool/ci_build.sh: intentos más finos (completa → sin huella → sin OCR → sin notificaciones → lite)
  y un resumen del motivo de cada fallo en la pestaña "Summary" de la ejecución de GitHub Actions.

## 1.4.0
Rendimiento (arranque):
- La pantalla de carga aparece al instante; la base de datos se abre después, con las 4 cajas en paralelo.
- Las 4 pestañas ya no se construyen todas al inicio: solo la que se abre.
- Tareas pesadas (recurrentes, papelera, descarga de tasas, respaldo automático) esperan a que la
  primera pantalla ya esté dibujada. Ventana de arranque nativa con el color de la app (sin negro).
- Lista de gastos en tandas de 40 y caché de la lista ordenada.
Funciones nuevas:
- Cuentas (efectivo, tarjeta, banco, ahorros) con saldos y transferencias entre ellas.
- Etiquetas (#viaje) y filtro por etiqueta.
- Detección automática de suscripciones y vista anual.
- Evolución de tasas (historial local) y alertas ("avísame si 1 USD llega a X BRL").
- Notificaciones programadas (cobros por vencer, día de pago, recordatorio diario y de respaldo).
- Atajos al mantener pulsado el icono (añadir gasto, escanear factura, conversor).
- Reporte PDF con gráfico de barras por categoría.
Build: tres niveles de respaldo automático (completa, sin notificaciones, lite).
Compatibilidad: los datos existentes se conservan (campos nuevos opcionales).

## 1.3.2
- Barra de estado de las tasas rediseñada: compacta (estado + hora de la última descarga
  en una línea, fecha del proveedor en letra pequeña) con un botón de información que
  explica las dos fechas, la fuente y las tasas por hora.

## 1.3.1
- Tasas de cambio transparentes: se muestran por separado la fecha de los datos del
  proveedor y la de la última descarga, con la fuente; el botón de actualizar avisa si
  hubo datos nuevos, si el proveedor aún no publicó o si falló.
- Varias fuentes gratuitas consultadas a la vez (gana la más reciente, completa las
  divisas que falten) y nunca se reemplazan datos nuevos por otros más viejos.
- Tasas cada hora (opcional) con una clave gratuita de Open Exchange Rates.
- Editor visual de mods: un color genera toda la paleta; vista previa, aviso de
  contraste, "Mis mods" guardados, pegar un mod como texto y compartirlo como archivo.

## 1.3.0
- Ingresos recurrentes (semanal, cada 2 semanas, quincenal 15 y fin de mes, mensual, anual).
- Presupuesto por periodo de pago, sobrante mensual, próximo pago y análisis por periodo.
- Escaneo de facturas (OCR local), foto adjunta al gasto, importación desde Excel (.xlsx).
- Autocompletado, dividir cuentas, deudas y préstamos, reporte mensual en PDF.
- Huella dactilar, recordatorio de respaldo.
- Workflow: firma estable (ver SIGNING.md), verificación del certificado y plan B "lite".
Compatibilidad: los datos existentes se conservan (campos nuevos opcionales).

## 1.2.0
Macro actualización 1 (espacios, PIN, papelera, categorías propias, tasas manuales, mods...).

## 1.1.0
Reparación sobre la 1.0.

## 1.0.0
Versión original.
