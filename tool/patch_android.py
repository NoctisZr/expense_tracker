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

android = sys.argv[1]
with_notifications = len(sys.argv) > 2 and sys.argv[2] == "1"

LIGHT_BG = "#F4F5F9"
DARK_BG = "#16171F"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def log(msg):
    print(f"[patch_android] {msg}")


# ---------------------------------------------------------------- manifest
def patch_manifest():
    path = os.path.join(android, "app/src/main/AndroidManifest.xml")
    if not os.path.exists(path):
        log("AndroidManifest.xml no encontrado")
        return
    text = read(path)

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
        extra = '        <item name="android:windowSplashScreenBackground">@color/launch_bg</item>\n' if splash else ""
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


patch_manifest()
patch_main_activity()
patch_launch_theme()
patch_gradle()
