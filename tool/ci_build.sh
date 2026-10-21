#!/usr/bin/env bash
# Compila el APK con varios intentos para que un plugin nativo problemático
# nunca deje al usuario sin APK, perdiendo solo lo mínimo:
#   1) completa            : todo (OCR, huella, notificaciones, atajos)
#   2) sin-huella          : sin local_auth
#   3) sin-ocr             : sin ML Kit (escaneo de facturas)
#   4) sin-notificaciones  : sin avisos programados ni atajos de pantalla
#   5) lite                : sin ninguno de los tres
# Cada fallo se resume en la pestaña "Summary" de la ejecución (con el motivo).
# Variables opcionales (secretos de firma): KEYSTORE_B64, KEYSTORE_PASSWORD,
# KEY_ALIAS, KEY_PASSWORD. Requiere /tmp/scaffold (flutter create).
set -u
SCAFFOLD="${SCAFFOLD:-/tmp/scaffold}"
LOGDIR="${RUNNER_TEMP:-/tmp}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
ENVFILE="${GITHUB_ENV:-/dev/null}"

signing_props() {
  if [ -z "${KEYSTORE_B64:-}" ]; then
    echo "::warning::Sin secretos de firma: el APK se firma con la clave de depuración (cada build distinta; no se puede instalar encima del anterior)."
    return 0
  fi
  echo "$KEYSTORE_B64" | base64 -d > "$LOGDIR/upload-keystore.jks"
  {
    echo "android.injected.signing.store.file=$LOGDIR/upload-keystore.jks"
    echo "android.injected.signing.store.password=${KEYSTORE_PASSWORD:-}"
    echo "android.injected.signing.key.alias=${KEY_ALIAS:-}"
    echo "android.injected.signing.key.password=${KEY_PASSWORD:-}"
  } >> android/gradle.properties
  echo "SIGNED=true" >> "$ENVFILE"
}

prepare_android() {   # $1 = 1 con notificaciones, 0 sin ellas
  rm -rf android
  cp -r "$SCAFFOLD/android" android
  python3 tool/patch_android.py android "$1"
  signing_props
}

strip_ocr() {
  sed -i '/google_mlkit_text_recognition/d' pubspec.yaml
  cp tool/lite/receipt_ocr_service.dart lib/services/receipt_ocr_service.dart
}
strip_biometrics() {
  sed -i '/local_auth:/d' pubspec.yaml
  cp tool/lite/biometric_service.dart lib/services/biometric_service.dart
}
strip_notifications() {
  sed -i '/flutter_local_notifications/d;/^  timezone:/d;/quick_actions:/d' pubspec.yaml
  cp tool/lite/notification_service.dart lib/services/notification_service.dart
  cp tool/lite/quick_actions_service.dart lib/services/quick_actions_service.dart
}
reset_sources() { git checkout -- pubspec.yaml lib/services; }

summarize_failure() {   # $1 = etiqueta, $2 = archivo de log
  {
    echo "### ❌ Falló el intento \"$1\""
    echo
    echo '```'
    {
      grep -n -A8 "What went wrong" "$2" | head -40
      grep -m 8 -E "Missing class|R8:|Could not resolve|requires libraries|Execution failed|error:" "$2"
    } | cut -c1-240
    echo '```'
  } >> "$SUMMARY"
  echo "::warning::El intento \"$1\" falló. El motivo está en el resumen de la ejecución."
}

attempt() {   # $1 = etiqueta, $2 = 1 con notificaciones / 0 sin ellas
  local label="$1" log="$LOGDIR/build_$1.log" status
  echo "=============== Intento: $label ==============="
  prepare_android "$2"
  # --split-per-abi: un APK por arquitectura (el "gordo" repite el motor y ML Kit 3 veces).
  # --split-debug-info: quita los símbolos de depuración de libapp.so (más pequeño).
  { flutter pub get && flutter build apk --release --split-per-abi --split-debug-info=build/symbols; } 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then summarize_failure "$label" "$log"; fi
  return "$status"
}

MODE=""
if attempt "completa" 1; then
  MODE="completa"
else
  reset_sources; strip_biometrics
  if attempt "sin-huella" 1; then
    MODE="sin-huella"
  else
    reset_sources; strip_ocr
    if attempt "sin-ocr" 1; then
      MODE="sin-ocr"
    else
      reset_sources; strip_notifications
      if attempt "sin-notificaciones" 0; then
        MODE="sin-notificaciones"
      else
        reset_sources; strip_ocr; strip_biometrics; strip_notifications
        if attempt "lite" 0; then
          MODE="lite"
        else
          echo "::error::Fallaron todos los intentos de compilación."
          exit 1
        fi
      fi
    fi
  fi
fi

echo "BUILD_MODE=$MODE" >> "$ENVFILE"
{
  echo "### ✅ Modo de compilación: $MODE"
  case "$MODE" in
    completa) echo "Incluye escaneo de facturas, huella, notificaciones y atajos." ;;
    sin-huella) echo "Sin desbloqueo por huella (el PIN sí funciona)." ;;
    sin-ocr) echo "Sin escaneo de facturas." ;;
    sin-notificaciones) echo "Sin notificaciones ni atajos de pantalla." ;;
    lite) echo "Sin escaneo de facturas, huella ni notificaciones." ;;
  esac
} >> "$SUMMARY"
echo "Modo de compilación: $MODE"
