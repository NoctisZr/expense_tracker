#!/usr/bin/env python3
"""Prepara el release de GitHub: etiqueta, nombre, notas (desde CHANGELOG.md) y
APK renombrados en la carpeta dist/. Escribe las salidas en $GITHUB_OUTPUT."""
import os
import re
import shutil

APK_DIR = "build/app/outputs/flutter-apk"


def read_app_name():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app_name.txt")
    try:
        with open(path, encoding="utf-8") as f:
            name = f.read().strip()
    except OSError:
        name = ""
    return name or "Peculio"


APP = read_app_name()
SLUG = re.sub(r"[^A-Za-z0-9]+", "", APP) or "App"

with open("pubspec.yaml", encoding="utf-8") as f:
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)", f.read(), re.M)
version, build = m.group(1), m.group(2)
tag = f"v{version}-{build}"
mode = os.environ.get("BUILD_MODE", "?")

notes = ""
if os.path.exists("CHANGELOG.md"):
    with open("CHANGELOG.md", encoding="utf-8") as f:
        changelog = f.read()
    section = re.search(rf"^##\s+{re.escape(version)}\s*$(.*?)(?=^##\s|\Z)", changelog, re.M | re.S)
    if section:
        notes = section.group(1).strip()
if not notes:
    notes = "Mejoras y correcciones."

body = f"""## {APP} {version} (build {build})

{notes}

---
### Cómo instalar
- Descarga **`{SLUG}-{version}-arm64-v8a.apk`** (casi todos los teléfonos desde ~2016) e instálalo.
- `…-armeabi-v7a.apk` es solo para teléfonos muy antiguos de 32 bits.
- Si ya tienes la app, instálalo encima: tus datos se conservan (siempre que el APK esté firmado con la misma clave).

_Modo de compilación: {mode}_
"""
with open("release_notes.md", "w", encoding="utf-8") as f:
    f.write(body)

os.makedirs("dist", exist_ok=True)
copied = []
for abi in ("arm64-v8a", "armeabi-v7a"):
    src = os.path.join(APK_DIR, f"app-{abi}-release.apk")
    if os.path.exists(src):
        dst = os.path.join("dist", f"{SLUG}-{version}-{abi}.apk")
        shutil.copyfile(src, dst)
        copied.append(dst)

out = os.environ.get("GITHUB_OUTPUT")
if out:
    with open(out, "a", encoding="utf-8") as f:
        f.write(f"tag={tag}\nversion={version}\nbuild={build}\napp={APP}\nslug={SLUG}\nname={APP} {version} (build {build})\n")
print(f"[release_notes] tag={tag} apks={copied}")
