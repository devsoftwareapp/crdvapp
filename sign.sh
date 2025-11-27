#!/bin/bash
set -e
set -x

echo "🛠️ Signing release APK and AAB with keystore"

# GitHub Actions secrets
KEYSTORE_BASE64="${KEYSTORE_BASE64}"
KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD}"
KEY_PASSWORD="${KEY_PASSWORD}"
KEY_ALIAS="${KEY_ALIAS}"

# Keystore decode
echo "$KEYSTORE_BASE64" | base64 --decode > release-key.jks

# build.json oluştur
cat > build.json <<EOF
{
  "android": {
    "release": {
      "keystore": "release-key.jks",
      "storePassword": "${KEYSTORE_PASSWORD}",
      "alias": "${KEY_ALIAS}",
      "password" : "${KEY_PASSWORD}",
      "keystoreType": "jks"
    }
  }
}
EOF

# Signed APK
cordova build android --release -- --packageType=apk --buildConfig=build.json
echo "✅ Signed Release APK built"

# Signed AAB
cordova build android --release -- --packageType=bundle --buildConfig=build.json
echo "✅ Signed Release AAB built"
