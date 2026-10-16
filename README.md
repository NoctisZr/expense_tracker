# Expense Tracker

App de finanzas personales para Android hecha con Flutter (Material 3):
balance basado en tus ingresos reales, bóvedas de ahorro multi-divisa con
proyección, calendario de gastos, resumen por categoría, conversor de
divisas en tiempo real, respaldo/exportación de datos y un sistema de
**mods** para personalizar la apariencia a fondo.

## Stack técnico

| Capa | Paquete |
|---|---|
| Framework | Flutter (Material 3) |
| Base de datos local | `hive` + `hive_flutter` |
| Estado global | `provider` |
| Gráfico donut | `fl_chart` |
| Tasas de cambio | `http` contra `open.er-api.com` (API abierta, sin API key) |
| Exportar/compartir respaldo | `path_provider` + `share_plus` |
| Importar respaldo / cargar mod | `file_picker` |
| Fondo personalizado | `image_picker` + `image` (resize + blur) |

Los `TypeAdapter` de Hive están escritos a mano en `lib/models/` — no
hace falta `build_runner`.

## Cómo compilarlo SIN una PC (GitHub Actions)

`.github/workflows/build.yml` compila el APK en los servidores de GitHub
cada vez que subes el código.

1. Sube el contenido de este ZIP a la **raíz** de un repo de GitHub
   (`lib/`, `mods/`, `pubspec.yaml` y `.github/` directo en la raíz).
2. Pestaña **Actions**: el workflow "Compilar APK" arranca solo (~5 min).
3. Al terminar, descarga el `.apk` desde la pestaña **Releases**.

El ZIP solo trae `lib/` y `pubspec.yaml`; el workflow genera un
proyecto Flutter temporal para tomar prestada su carpeta `android/`,
le agrega el permiso de Internet y compila. El `dependency_overrides`
de `flutter_plugin_android_lifecycle` en el `pubspec.yaml` evita que
esa dependencia transitiva exija un compileSdk más nuevo que el que
trae el scaffold por defecto.

## Estructura

```
.github/workflows/build.yml       # CI: compila y publica el APK
mods/                              # Mods de ejemplo (.json) para Ajustes
pubspec.yaml
lib/
├── main.dart
├── models/      # Expense, Income, Vault, VaultTransaction, ModTheme
├── providers/   # Theme, Locale, Currency, Finance
├── services/    # CurrencyApi, Backup, BackgroundImage
├── l10n/        # Español, Inglés, Portugués
├── utils/       # Tema, colores, formas de mods, proyecciones
├── screens/     # Dashboard, Conversor, Ajustes, Home
└── widgets/     # Donut, calendario, tarjetas, diálogos, máscara/acentos de mods
```

## Funciones

- **Ingresos y balance:** registra cada pago (etiqueta, monto, divisa,
  fecha). El donut del dashboard reparte el ingreso más reciente entre
  Gastos, Bóvedas y Disponible desde su fecha hasta hoy — sin sueldo
  fijo que mantener a mano. Tocando un ingreso ves cuánto se gastó, en
  cuántos días, el ritmo diario y, si es el último, en cuántos días se
  agotaría.
- **Bóvedas:** metas de ahorro donde puedes aportar en una divisa distinta
  a la de la meta (se convierte y se guarda la tasa usada), con historial
  y proyección de cuánto falta según tu ritmo real. Al **retirar**,
  eliges si el dinero vuelve a "Disponible" o si "Fue un gasto": en ese
  caso pones nombre y categoría y se registra el gasto automáticamente.
- **Gastos:** por categoría (Compras/Servicios/Comida/Otros), en lista o
  calendario mensual, con un **resumen por categoría** (por separado
  con barras, o total combinado).
- **Conversor** con tasas en tiempo real (cacheadas offline) y spread.
  Las tasas se refrescan al abrir la app y al volver a ella (máx. 1 vez
  por hora).
- **Respaldo:** exportar/importar todos tus datos (`.json`) vía el
  panel de Compartir de Android, para guardarlos en tu nube o pasarlos a
  otro celular. No es sincronización automática: eso requeriría un
  backend propio con credenciales tuyas.
- **Fondo personalizado:** tu foto se reduce y se desenfoca UNA vez al
  elegirla (en un isolate aparte), así que mostrarla no cuesta
  rendimiento en el uso diario.

## Mods: personalización visual profunda

En Ajustes → "Personalización avanzada" cargas un archivo `.json` que
cambia la apariencia de TODA la app. **Cualquier mod puede usar
cualquier propiedad** — nada está atado a un mod en particular. Todo es
opcional excepto `"name"`; lo que no pongas usa el valor por defecto.

Es **solo apariencia, nunca código ni lógica**: una app Flutter se
compila a binario nativo y no puede ejecutar de forma segura código
ajeno (a diferencia de un mod de Minecraft en una JVM). Un mod solo
puede dar colores, números, palabras clave de un catálogo fijo y, como
mucho, una imagen estática — en el peor caso se ve raro, nunca rompe
algo.

```json
{
  "name": "Nombre del mod",
  "author": "Quien lo hizo",
  "description": "Se muestra en Ajustes",
  "preferredBrightness": "dark",
  "colors": {
    "background": "#121114", "card": "#1C1B1F", "cardAlt": "#26242A",
    "accent": "#C9A15C", "accentSecondary": "#EDEAE2",
    "textPrimary": "#E8E5DE", "textSecondary": "#8A877E",
    "warning": "#A13A3A", "expense": "#9C6B3E", "vault": "#5A7A8A",
    "success": "#6E8264", "danger": "#A13A3A", "border": "#3A3833"
  },
  "style": {
    "cardRadius": 5, "buttonRadius": 4,
    "cardShape": "beveled", "buttonShape": "beveled",
    "cardStyle": "outlined", "buttonStyle": "outlined",
    "borderWidth": 1.1, "elevation": 0, "density": "compact",
    "cornerAccent": "brackets", "cornerAccentColor": "#C9A15C"
  },
  "overlay": { "pattern": "scanlines", "opacity": 0.05 }
}
```

| Propiedad | Valores |
|---|---|
| `preferredBrightness` | `light` / `dark` (cambia el modo solo al cargar el mod) |
| `cardShape`, `buttonShape` | `rounded` (por defecto), `beveled` (esquinas cortadas a 45°, como el filo de una hoja), `stadium` (píldora), `continuous` (squircle) |
| `cardStyle` | `filled` / `outlined` |
| `buttonStyle` | `filled` / `outlined` / `text` |
| `density` | `compact` / `comfortable` / `spacious` |
| `cornerAccent` | `none` / `brackets` (corchetes tipo HUD en las tarjetas) |
| `overlay.pattern` | `none` / `scanlines` / `grid` (dibujados por código, encima de toda la app) |
| `overlay.imageBase64` | (avanzado) una textura propia en base64; si está, reemplaza al patrón |

Mods incluidos, cada uno con una forma distinta a propósito para mostrar
que el sistema es general: `madoka_kaname.json` (claro, pastel, píldora),
`ejemplo_aurora.json` (squircle + grilla de estrellas),
`ejemplo_atardecer.json` (clásico redondeado, compacto) y
`yorha_nier_automata.json` (2B: negro/blanco/dorado, biselado tipo
espada, corchetes HUD y scanlines).

Elegir un color de la paleta de "Color del Tema" desactiva el mod cargado.

## Nota sobre `hive_flutter`

Se usa `hive_flutter` como se pidió. El paquete original ya no recibe
actualizaciones; si algún día hay problemas de compatibilidad con un
Flutter muy nuevo, `hive_ce` / `hive_ce_flutter` es un reemplazo casi
directo (mismo API).


## Novedades de la v1.1

- **Espacios de trabajo** (Personal, Negocio, lo que quieras): cada uno
  con sus propios gastos, ingresos, bóvedas, presupuestos y recurrentes.
  "Personal" usa las cajas originales, así que tus datos no se mueven.
- **Presupuesto mensual por categoría** con barras y aviso al llegar al
  80 % y al pasarte.
- **Gastos recurrentes** (suscripciones, alquiler): se registran solos
  cada mes.
- **Calculadora de envíos** (peso real vs. volumétrico, aéreo/express/
  personalizado) con conversión a tu moneda local y botón para guardarla
  como gasto.
- **Editar gastos** tocándolos, **búsqueda y filtro por categoría**.
- **Exportar gastos a CSV** (Excel / Google Sheets).
- Moneda e idioma iniciales según la región del teléfono (solo el primer
  arranque).
- Equivalente en moneda local (≈) en cada bóveda de otra divisa.
- Más divisas soportadas (AUD, CHF, CNY, KRW, INR, UYU, BOB, PYG, DOP,
  GTQ, CRC, PAB).
