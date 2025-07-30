#!/bin/bash
# scripts/build_apk_template.sh

set -e

PROJECT_NAME="$1"
OUTPUT_DIR="$2"

if [ -z "$PROJECT_NAME" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: $0 <project-name> <output-dir>"
  exit 1
fi

TEMPLATE="flutter/assets/templates/android"
OUTPUT="$OUTPUT_DIR/$PROJECT_NAME.apk"

echo "Building APK for $PROJECT_NAME..."

# Copy template
cp -r "$TEMPLATE" "$OUTPUT_DIR/app"
cd "$OUTPUT_DIR/app"

# Inject app name
sed -i.bak "s/APP_NAME/$PROJECT_NAME/g" app/src/main/res/values/strings.xml
rm *.bak

# Build APK
./gradlew build

cp app/build/outputs/apk/debug/app-debug.apk "$OUTPUT"

echo "APK built: $OUTPUT"