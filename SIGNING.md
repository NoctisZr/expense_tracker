# Firma estable del APK (para poder actualizar la app sin desinstalarla)

Android solo instala una actualización encima de la app existente si el APK
nuevo está firmado con **la misma clave** que el anterior. Sin firma propia,
cada build de GitHub Actions usa una clave de depuración distinta y Android
rechaza la actualización.

## 1. Crear tu clave (una sola vez, en el Codespace)

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Te pedirá una contraseña del almacén, tus datos y una contraseña de la clave.
**Guárdalas en un gestor de contraseñas.**

## 2. Guardar una copia segura

Descarga `upload-keystore.jks` desde el explorador del Codespace y guárdalo en
tu nube/USB. **Si pierdes este archivo o su contraseña, nunca más podrás
actualizar la app instalada** (tendrías que desinstalar y reinstalar).

## 3. Subir la clave a GitHub como "secretos"

```bash
base64 -w 0 upload-keystore.jks > keystore.b64
cat keystore.b64     # copia todo el texto
```

En GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
Crea estos cuatro:

| Nombre | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | el contenido de `keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | la contraseña del almacén |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | la contraseña de la clave |

## 4. Limpiar y proteger

```bash
rm keystore.b64 upload-keystore.jks
printf '\n*.jks\n*.keystore\n*.b64\nkey.properties\n' >> .gitignore
```

**Nunca subas el `.jks` ni los secretos al repositorio.**

## 5. Compilar

Haz push (o ejecuta el workflow a mano). En el resumen de la ejecución verás
el certificado del APK. Anota su huella SHA-256: debe ser **idéntica en todos
los builds futuros**.

## Primera instalación con firma propia

Como el APK actual está firmado con otra clave, esa primera vez Android no
dejará instalar encima. Haz esto:

1. En la app actual: **Ajustes → Exportar datos** y guarda el archivo en tu nube.
2. Desinstala la app.
3. Instala el APK nuevo (ya con firma propia).
4. **Ajustes → Importar datos → Reemplazar** y elige tu respaldo.

A partir de ahí, cada versión se instala encima sin perder nada.

## Si algo falla

El workflow avisa con `::warning::` si hay secretos pero el APK sigue firmado
con la clave de depuración. En ese caso, envía el log del paso "Mostrar con
qué certificado quedó firmado el APK".
