#!/bin/bash
# scripts/sign_apk.sh

APK="$1"
KEYSTORE="keys/sprout.jks"

if [ ! -f "$APK" ]; then
  echo "APK not found: $APK"
  exit 1
fi

echo "Signing $APK..."
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore "$KEYSTORE" "$APK" sprout_key

echo "Aligned and signed."