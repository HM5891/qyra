#!/data/data/com.termux/files/usr/bin/bash
# Qyra: create the PERMANENT signing key for both APKs (run once in Termux):
#   bash ~/qyra/tools/setup_signing.sh
# Uses OpenSSL (Java's keytool crashes on some phones). The key stays in ~/qyra-keys.
# GitHub only gets it as encrypted Actions secrets. Keep ~/qyra-keys safe.
set -e
REPO="HM5891/qyra"; KEYDIR="$HOME/qyra-keys"; mkdir -p "$KEYDIR"; cd "$KEYDIR"
command -v openssl >/dev/null 2>&1 || pkg install -y openssl-tool </dev/null
command -v gh >/dev/null 2>&1 || pkg install -y gh </dev/null
if [ -s qyra.jks ] && [ -s password.txt ]; then
  echo "Key already exists in $KEYDIR - keeping it."
else
  PASS=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)
  echo "$PASS" > password.txt
  openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 10000 -subj "/CN=Qyra/O=Qyra/C=IN"
  openssl pkcs12 -export -in cert.pem -inkey key.pem -name qyra -out qyra.jks -passout pass:"$PASS"
  rm -f key.pem; chmod 600 qyra.jks password.txt
  echo "Created new key in $KEYDIR"
fi
gh auth status >/dev/null 2>&1 || gh auth login
base64 -w0 qyra.jks | gh secret set QYRA_KEYSTORE_BASE64 -R "$REPO"
gh secret set QYRA_KEYSTORE_PASSWORD -R "$REPO" --body "$(cat password.txt)"
echo "Done. Next builds of Qyra and Qyra Admin are signed with your permanent key."
