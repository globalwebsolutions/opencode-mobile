#!/usr/bin/env bash
# Creates the Google Play upload keystore and points the build at it.
#
#   bash tools/make_upload_keystore.sh [alias] [keystore-path]
#
# Defaults: alias "upload", keystore ~/opencode-upload.jks
#
# ⚠️ حفظ نسخة احتياطية من ملف الـ .jks ومن كلمة السر. لو ضاع، مش هتقدر ترفع
# تحديث للتطبيق (إلا لو Play App Signing مفعّل وGoogle شايلة مفتاح التوقيع).
set -euo pipefail

ALIAS="${1:-upload}"
KEYSTORE="${2:-$HOME/opencode-upload.jks}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "$KEYSTORE" ]]; then
  echo "الملف موجود بالفعل: $KEYSTORE" >&2
  echo "امسحه أو غيّر المسار لو عايز تعمل واحد جديد." >&2
  exit 1
fi

read -rsp "كلمة سر الـ keystore: " STORE_PASS; echo
read -rsp "كلمة سر المفتاح (Enter = نفس الأولى): " KEY_PASS; echo
[[ -z "$KEY_PASS" ]] && KEY_PASS="$STORE_PASS"

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STORE_PASS" -keypass "$KEY_PASS" \
  -dname "CN=Global Web Solutions, O=Global Web Solutions, C=EG"

cat > "$ROOT/android/key.properties" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=$KEYSTORE
EOF

chmod 600 "$ROOT/android/key.properties" "$KEYSTORE"

echo
echo "✅ اتكتب $ROOT/android/key.properties"
echo "   دلوقتي: flutter build appbundle --release"
echo
echo "🔐 اعمل باك أب لـ $KEYSTORE بره الجهاز — من غيره مش هينفع تحدّث التطبيق."
