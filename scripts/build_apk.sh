#!/bin/bash
# scripts/build_apk.sh

PROJECT_NAME="$1"
PROJECT_DIR="$2"
OUTPUT_DIR="$3"

TEMPLATE="flutter/assets/templates/android"
BUILD_DIR="/tmp/sprout_build_${PROJECT_NAME}"

rm -rf "$BUILD_DIR"
cp -r "$TEMPLATE" "$BUILD_DIR"

# Replace placeholders
find "$BUILD_DIR" -type f -exec sed -i "s/APP_NAME/$PROJECT_NAME/g" {} \;

# Copy WASM or logic
echo "console.log('App logic here');" > "$BUILD_DIR/app/src/main/assets/logic.js"

cd "$BUILD_DIR"
./gradlew assembleDebug

cp app/build/outputs/apk/debug/app-debug.apk "$OUTPUT_DIR/${PROJECT_NAME}.apk"
echo "APK generated: $OUTPUT_DIR/${PROJECT_NAME}.apk"