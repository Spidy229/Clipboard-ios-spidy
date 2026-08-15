#!/bin/bash
set -euo pipefail

rm -rf build Payload Super-Portapapeles-unsigned.ipa

xcodegen generate --spec project.yml

xcodebuild \
  -project SuperPortapapeles.xcodeproj \
  -scheme SuperPortapapeles \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  clean build

APP_PATH="build/Build/Products/Release-iphoneos/SuperPortapapeles.app"
test -d "$APP_PATH"

mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry Super-Portapapeles-unsigned.ipa Payload

unzip -t Super-Portapapeles-unsigned.ipa
ls -lh Super-Portapapeles-unsigned.ipa

