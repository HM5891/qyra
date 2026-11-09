#!/data/data/com.termux/files/usr/bin/bash
# Qyra: create the PERMANENT signing key for both APKs (run once in Termux):
#   bash ~/qyra/tools/setup_signing.sh
# The key stays in ~/qyra-keys on your phone. GitHub only gets it as encrypted Actions secrets.
# Keep ~/qyra-keys safe: without it, future APKs can't update the installed apps.
set -e
REPO="HM5891/qyra"; KEYDIR="$HOME/qyra-keys"; mkdir -p "$KEYDIR"
command -v keytool >/dev/null 2>&1 || pkg install -y openjdk-17
command -v gh >/dev/null 2>&1 || pkg install -y gh
if [ -f "$KEYDIR/qyra.jks" ]; then
  echo "Key already exists in $KEYDIR - keeping it."
  PASS=$(cat "$KEYDIR/password.txt")
else
  PASS=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)
  keytool -genkeypair -keystore "$KEYDIR/qyra.jks" -storetype JKS -alias qyra -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass "$PASS" -keypass "$PASS" -dname "CN=Qyra, O=Qyra, C=IN"
  echo "$PASS" > "$KEYDIR/password.txt"; chmod 600 "$KEYDIR/password.txt" "$KEYDIR/qyra.jks"
  echo "Created new key in $KEYDIR"
fi
gh auth status >/dev/null 2>&1 || gh auth login
base64 -w0 "$KEYDIR/qyra.jks" | gh secret set QYRA_KEYSTORE_BASE64 -R "$REPO"
printf '%s' "$PASS" | gh secret set QYRA_KEYSTORE_PASSWORD -R "$REPO"
echo "Done. Next builds of Qyra and Qyra Admin are signed with your permanent key."
