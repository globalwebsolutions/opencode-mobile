#!/usr/bin/env bash
# Captures Play Store screenshots from a phone connected over USB.
#
# Interactive on purpose: it asks you to open each screen and waits for Enter,
# so the shots are always of the current UI.
#
#   bash tools/capture_store_screenshots.sh [device-serial]
#
# Output: store/screenshots/raw/*.png + store/screenshots/store_*.png
set -euo pipefail

DEVICE="${1:-$(adb devices | awk 'NR==2{print $1}')}"
if [[ -z "${DEVICE}" ]]; then
  echo "no device found: connect a phone over USB (adb devices)" >&2
  exit 1
fi

RAW="store/screenshots/raw"
mkdir -p "$RAW"

shoot() {
  local name="$1" caption="$2"
  read -r -p "→ افتح: ${caption}  ثم اضغط Enter للتصوير (أو s للتخطي) " answer
  if [[ "${answer}" == "s" ]]; then
    echo "   skipped ${name}"
    return
  fi
  adb -s "${DEVICE}" exec-out screencap -p > "${RAW}/${name}.png"
  echo "   saved ${RAW}/${name}.png"
}

echo "📸 صور المتجر — الموبايل: ${DEVICE}"
echo "   كل لقطة بتحفظ كما هي، وبعدها بتحوّل لمقاسات جوجل."
echo

shoot 01_home        "الشاشة الرئيسية (Home)"
shoot 02_chat        "محادثة فيها كروت أدوات + تفكير"
shoot 03_permission  "كارت طلب الصلاحية (سماح/رفض)"
shoot 04_projects    "المشاريع والمحادثات"
shoot 05_picker      "شيت اختيار المشروع أو الموديل"
shoot 06_settings    "الإعدادات (اللغة/المظهر/الإشعارات)"

echo
echo "🎨 بتحويل الصور لمقاس المتجر (1080×2160)…"
python3 tools/storeify_screenshots.py "${RAW}"/*.png

echo
echo "✅ جاهزة في store/screenshots/ — ارفعها في Play Console → Store listing → Phone screenshots"
