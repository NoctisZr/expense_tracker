#!/usr/bin/env bash
# Compila el APK con tres niveles de seguridad para que un plugin nativo
# problemático nunca deje al usuario sin APK:
#   1) completa  : todo (OCR, huella, notificaciones, atajos)
#   2) sin avisos: sin notificaciones ni atajos de pantalla
#   3) lite      : además sin OCR de facturas ni huella
# Variables opcionales (secretos de firma): KEYSTORE_B64, KEYSTORE_PASSWORD,
# KEY_ALIAS, KEY_PASSWORD. Requiere que /tmp/scaffold exista (flutter create).
set -u
SCAFFOLD=/tmp/scaffold

signing_props() {
  if [ -z "${KEYSTORE_B64:-}" ]; then
    echo "::warning::Sin secretos de firma: el APK se firma con la clave de depuración (cada build distinta; no se puede instalar encima del anterior)."
    return 0
  fi
  echo "$KEYSTORE_B64" | base64 -d > "$RUNNER_TEMP/upload-keystore.jks"
  {
    echo "android.injected.signing.store.file=$RUNNER_TEMP/upload-keystore.jks"
    echo "android.injected.signing.store.password=${KEYSTORE_PASSWORD:-}"
    echo "android.injected.signing.key.alias=${KEY_ALIAS:-}"
    echo "android.injected.signing.key.password=${KEY_PASSWORD:-}"
  } >> android/gradle.properties
  echo "SIGNED=true" >> "$GITHUB_ENV"
}

prepare_android() {   # $1 = 1 con notificaciones, 0 sin ellas
  rm -rf android
  cp -r "$SCAFFOLD/android" android
  python3 tool/patch_android.py android "$1"
  signing_props
}

strip_notifications() {
  sed -i '/flutter_local_notifications/d;/^  timezone:/d;/quick_actions:/d' pubspec.yaml
  cp tool/lite/notification_service.dart lib/services/notification_service.dart
  cp tool/lite/quick_actions_service.dart lib/services/quick_actions_service.dart
}

strip_ocr_and_biometrics() {
  sed -i '/google_mlkit_text_recognition/d;/local_auth:/d' pubspec.yaml
  cp tool/lite/receipt_ocr_service.dart lib/services/receipt_ocr_service.dart
  cp tool/lite/biometric_service.dart lib/services/biometric_service.dart
}

build() { flutter pub get && flutter build apk --release; }

MODE=""
prepare_android 1
if build; then
  MODE="completa"
else
  echo "::warning::El build completo falló. Reintentando sin notificaciones ni atajos de pantalla."
  strip_notifications
  prepare_android 0
  if build; then
    MODE="sin-notificaciones"
  else
    echo "::warning::También falló. Reintentando versión lite (sin OCR de facturas ni huella)."
    strip_ocr_and_biometrics
    prepare_android 0
    if build; then
      MODE="lite"
    else
      echo "::error::Fallaron los tres intentos de compilación."
      exit 1
    fi
  fi
fi

echo "BUILD_MODE=$MODE" >> "$GITHUB_ENV"
echo "Modo de compilación: $MODE"
