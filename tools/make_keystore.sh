#!/usr/bin/env bash
# Creates the Google Play UPLOAD key once and prints what to paste into GitHub secrets.
# Keep upload.keystore and the password safe: lose them and you can't update the app
# (Play App Signing lets you reset the upload key via support, but it takes days).
set -euo pipefail

read -r -s -p "Choose a keystore password (min 6 chars): " PASS
echo
keytool -genkeypair -v -keystore upload.keystore -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=Moonpull"

openssl base64 -A -in upload.keystore > upload.keystore.b64

echo
echo "Done. Add these secrets in GitHub: repo -> Settings -> Secrets and variables -> Actions:"
echo "  KEYSTORE_BASE64   = contents of upload.keystore.b64"
echo "  KEYSTORE_PASSWORD = the password you just typed"
echo "  KEY_ALIAS         = upload"
echo
echo "Then delete upload.keystore.b64 and back up upload.keystore somewhere safe (NOT in git)."
