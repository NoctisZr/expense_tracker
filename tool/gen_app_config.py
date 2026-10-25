#!/usr/bin/env python3
"""Genera lib/app_config.dart con la versión del pubspec y los datos del
repositorio. En CI se ejecuta antes de compilar, así la app siempre sabe qué
versión es y de qué repositorio de GitHub buscar actualizaciones.

Variables de entorno opcionales:
  REPO              owner/nombre del repositorio (para buscar actualizaciones)
  FEEDBACK_URL      URL del Worker de Telegram (para el botón de reportes)
  FEEDBACK_APP_KEY  clave que el Worker exige en la cabecera X-App-Key
"""
import os
import re

with open("pubspec.yaml", encoding="utf-8") as f:
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)", f.read(), re.M)
if not match:
    raise SystemExit("No se encontró 'version: x.y.z+n' en pubspec.yaml")
version, build = match.group(1), int(match.group(2))


def q(value):
    return "'" + (value or "").strip().replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


content = f"""// GENERADO por tool/gen_app_config.py (en CI se regenera en cada build).
// Los valores de repositorio y reportes salen de variables de GitHub Actions.

/// Versión de la app (viene de pubspec.yaml).
const String kAppVersion = {q(version)};

/// Número de build (lo que va después del "+" en pubspec.yaml).
const int kAppBuild = {build};

/// "owner/nombre" del repositorio de GitHub donde se publican los releases.
/// Vacío = sin comprobación de actualizaciones.
const String kGithubRepo = {q(os.environ.get('REPO', ''))};

/// URL del Worker que reenvía los reportes a Telegram. Vacío = sin envío directo.
const String kFeedbackUrl = {q(os.environ.get('FEEDBACK_URL', ''))};

/// Clave que se envía en la cabecera X-App-Key (no es secreta: solo frena el spam casual).
const String kFeedbackAppKey = {q(os.environ.get('FEEDBACK_APP_KEY', ''))};
"""
with open("lib/app_config.dart", "w", encoding="utf-8") as f:
    f.write(content)
print(f"[gen_app_config] versión {version} build {build}, repo='{os.environ.get('REPO', '')}'")
