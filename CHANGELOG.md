# Changelog

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
