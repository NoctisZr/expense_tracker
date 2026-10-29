#!/usr/bin/env python3
"""Prepara el proyecto Android recién generado por `flutter create`.

Uso: python3 tool/patch_android.py <carpeta android> <1|0>
  segundo argumento: 1 = incluir notificaciones programadas, 0 = sin ellas.

Solo usa la librería estándar y es idempotente. Si algo no se encuentra en la
plantilla (que cambia entre versiones de Flutter), lo avisa y sigue sin romper.
"""
import os
import re
import sys

try:
    from PIL import Image
except ImportError:
    Image = None

android = sys.argv[1]
with_notifications = len(sys.argv) > 2 and sys.argv[2] == "1"

LIGHT_BG = "#F2F8F7"
DARK_BG = "#061525"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def log(msg):
    print(f"[patch_android] {msg}")


def app_name():
    """Nombre visible de la app (tool/app_name.txt)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app_name.txt")
    try:
        name = read(path).strip()
    except OSError:
        name = ""
    return name or "Peculio"


# ---------------------------------------------------------------- manifest
def patch_manifest():
    path = os.path.join(android, "app/src/main/AndroidManifest.xml")
    if not os.path.exists(path):
        log("AndroidManifest.xml no encontrado")
        return
    text = read(path)

    # Nombre que se ve bajo el icono y en la lista de apps.
    label = app_name().replace("&", "&amp;").replace("<", "&lt;").replace('"', "&quot;")
    text, n_label = re.subn(r'android:label="[^"]*"', lambda m: f'android:label="{label}"', text, count=1)
    text, n_icon = re.subn(r'android:icon="[^"]*"', 'android:icon="@mipmap/ic_launcher"', text, count=1)
    log(f"nombre de la app: {label}" if n_label else "no se encontró android:label en el manifiesto")
    log("icono de Nuvio asignado" if n_icon else "no se encontró android:icon en el manifiesto")

    permissions = ["android.permission.INTERNET", "android.permission.USE_BIOMETRIC"]
    if with_notifications:
        permissions += [
            "android.permission.POST_NOTIFICATIONS",
            "android.permission.RECEIVE_BOOT_COMPLETED",
        ]
    missing = [p for p in permissions if p not in text]
    if missing:
        lines = "".join(f'\n    <uses-permission android:name="{p}"/>' for p in missing)
        text, n = re.subn(r"(<manifest[^>]*>)", lambda m: m.group(1) + lines, text, count=1)
        log(f"permisos añadidos: {', '.join(missing)}" if n else "no se pudo insertar permisos")

    if with_notifications and "ScheduledNotificationReceiver" not in text:
        receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    """
        text, n = re.subn(r"</application>", receivers + "</application>", text, count=1)
        log("receptores de notificaciones añadidos" if n else "no se encontró </application>")
    write(path, text)
    generate_launcher_icons()


def generate_launcher_icons():
    """Genera los iconos Android desde el PNG de marca incluido en assets."""
    if Image is None:
        log("Pillow no está instalado; se omite la generación del icono")
        return
    source = os.path.join(os.path.dirname(android), "assets", "nuvio_icon.png")
    if not os.path.exists(source):
        log("assets/nuvio_icon.png no encontrado; se omite el icono")
        return
    image = Image.open(source).convert("RGBA")
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        folder = os.path.join(android, f"app/src/main/res/mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        resized = image.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(folder, "ic_launcher.png"), optimize=True)
    log("iconos launcher generados para las cinco densidades Android")


# ------------------------------------------------------------ MainActivity
def patch_main_activity():
    found = False
    for root, _dirs, files in os.walk(os.path.join(android, "app/src/main")):
        for name in files:
            if name in ("MainActivity.kt", "MainActivity.java"):
                path = os.path.join(root, name)
                text = read(path)
                new = text.replace(
                    "io.flutter.embedding.android.FlutterActivity",
                    "io.flutter.embedding.android.FlutterFragmentActivity",
                ).replace("FlutterActivity()", "FlutterFragmentActivity()").replace(
                    "extends FlutterActivity", "extends FlutterFragmentActivity"
                )
                if new != text:
                    write(path, new)
                    log(f"{name} ahora usa FlutterFragmentActivity (huella)")
                found = True
    if not found:
        log("MainActivity no encontrada; la huella podría no funcionar (el PIN sí)")


# -------------------------------------------- ventana de arranque / splash
def patch_launch_theme():
    res = os.path.join(android, "app/src/main/res")
    write(os.path.join(res, "values/colors.xml"),
          f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="launch_bg">{LIGHT_BG}</color>\n</resources>\n')
    write(os.path.join(res, "values-night/colors.xml"),
          f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="launch_bg">{DARK_BG}</color>\n</resources>\n')

    drawable = ('<?xml version="1.0" encoding="utf-8"?>\n'
                '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <item android:drawable="@color/launch_bg" />\n'
                '</layer-list>\n')
    write(os.path.join(res, "drawable/launch_background.xml"), drawable)
    if os.path.isdir(os.path.join(res, "drawable-v21")):
        write(os.path.join(res, "drawable-v21/launch_background.xml"), drawable)

    def styles(parent, splash):
        extra = ('        <item name="android:windowSplashScreenBackground">@color/launch_bg</item>\n'
                 '        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>\n') if splash else ""
        return ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'    <style name="LaunchTheme" parent="{parent}">\n'
                '        <item name="android:windowBackground">@drawable/launch_background</item>\n'
                f'{extra}'
                '    </style>\n'
                f'    <style name="NormalTheme" parent="{parent}">\n'
                '        <item name="android:windowBackground">@color/launch_bg</item>\n'
                '    </style>\n</resources>\n')

    light = "@android:style/Theme.Light.NoTitleBar"
    night = "@android:style/Theme.Black.NoTitleBar"
    write(os.path.join(res, "values/styles.xml"), styles(light, False))
    write(os.path.join(res, "values-night/styles.xml"), styles(night, False))
    write(os.path.join(res, "values-v31/styles.xml"), styles(light, True))
    write(os.path.join(res, "values-night-v31/styles.xml"), styles(night, True))
    log("ventana de arranque y splash con color propio (sin pantalla negra)")


# -------------------------------------------------------------- desugaring
def patch_gradle():
    if not with_notifications:
        return
    kts = os.path.join(android, "app/build.gradle.kts")
    groovy = os.path.join(android, "app/build.gradle")
    if os.path.exists(kts):
        text = read(kts)
        if "isCoreLibraryDesugaringEnabled" not in text:
            text, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", text, count=1)
            if not n:
                log("no se encontró compileOptions en build.gradle.kts (desugaring NO aplicado)")
        if "coreLibraryDesugaring(" not in text:
            text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        write(kts, text)
        log("desugaring aplicado en build.gradle.kts")
    elif os.path.exists(groovy):
        text = read(groovy)
        if "coreLibraryDesugaringEnabled" not in text:
            text, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", text, count=1)
            if not n:
                log("no se encontró compileOptions en build.gradle (desugaring NO aplicado)")
        if "coreLibraryDesugaring '" not in text:
            text += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        write(groovy, text)
        log("desugaring aplicado en build.gradle")
    else:
        log("no se encontró build.gradle(.kts) de la app")


# ----------------------------------------------------------------- proguard
PROGUARD_RULES = """# --- Reglas añadidas por tool/patch_android.py ---
# ML Kit: el plugin de OCR referencia reconocedores de otros alfabetos
# (chino, japonés, coreano, devanagari) que no se incluyen. Sin estas líneas,
# R8 falla en el build release con "Missing class com.google.mlkit.vision.text...".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# flutter_local_notifications usa Gson con reflexión: sin esto, R8 puede romper
# las notificaciones programadas en release.
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keep class com.dexterous.flutterlocalnotifications.** { *; }
"""


def patch_proguard():
    path = os.path.join(android, "app/proguard-rules.pro")
    if os.path.exists(path):
        text = read(path)
        if "Reglas añadidas por tool/patch_android.py" not in text:
            write(path, text.rstrip("\n") + "\n\n" + PROGUARD_RULES)
    else:
        write(path, PROGUARD_RULES)
    log("reglas de R8 (ML Kit y notificaciones) escritas en proguard-rules.pro")

    # Se asegura de que el build release use el archivo.
    kts = os.path.join(android, "app/build.gradle.kts")
    groovy = os.path.join(android, "app/build.gradle")
    target = kts if os.path.exists(kts) else (groovy if os.path.exists(groovy) else None)
    if target is None:
        return
    text = read(target)
    if "proguard-rules.pro" in text:
        return
    start = text.find("buildTypes")
    if start == -1:
        log("no se encontró buildTypes; se confía en que el plugin de Flutter use proguard-rules.pro")
        return
    m = re.search(r"release\s*\{", text[start:])
    if not m:
        log("no se encontró el bloque release; se confía en el plugin de Flutter")
        return
    pos = start + m.end()
    line = '\n            proguardFiles("proguard-rules.pro")' if target == kts else "\n            proguardFiles 'proguard-rules.pro'"
    write(target, text[:pos] + line + text[pos:])
    log("proguardFiles añadido al bloque release")


patch_manifest()
patch_main_activity()
patch_launch_theme()
patch_proguard()
patch_gradle()
