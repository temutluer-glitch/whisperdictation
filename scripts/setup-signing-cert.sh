#!/usr/bin/env bash
# One-time setup: erstellt ein selbstsigniertes Code-Signing-Zertifikat
# "WhisperDictation Developer" und legt es im login-Keychain ab.
#
# Wird einmalig auf Timurs Build-Mac ausgeführt. Mitarbeiter brauchen das NICHT.
# Nutzt das so erzeugte Zertifikat danach automatisch in build-release.sh.

set -euo pipefail

CERT_NAME="WhisperDictation Developer"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Prüfe vorhandenes Zertifikat …"
if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "$CERT_NAME"; then
  echo "    Zertifikat '$CERT_NAME' existiert bereits. Nichts zu tun."
  security find-identity -v -p codesigning "$KEYCHAIN" | grep "$CERT_NAME"
  exit 0
fi

echo "==> Generiere RSA-Schlüssel + selbstsigniertes Code-Signing-Cert …"
cat > "$WORKDIR/openssl.cnf" <<'EOF'
[ req ]
default_bits        = 2048
default_md          = sha256
prompt              = no
distinguished_name  = dn
req_extensions      = v3_req
x509_extensions     = v3_req

[ dn ]
CN = WhisperDictation Developer
O  = InnoSolv
C  = DE

[ v3_req ]
basicConstraints     = critical, CA:false
keyUsage             = critical, digitalSignature
extendedKeyUsage     = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -days 7300 -nodes \
  -keyout "$WORKDIR/key.pem" \
  -out "$WORKDIR/cert.pem" \
  -config "$WORKDIR/openssl.cnf" \
  -extensions v3_req \
  >/dev/null 2>&1

P12_PASS="$(openssl rand -hex 16)"
# Default-Flags (3DES + SHA1 MAC) sind LibreSSL-default und macOS-kompatibel.
# OpenSSL 3.x (Homebrew) muss explizit -legacy bekommen.
PKCS12_LEGACY=""
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
  PKCS12_LEGACY="-legacy"
fi
openssl pkcs12 -export $PKCS12_LEGACY \
  -inkey "$WORKDIR/key.pem" \
  -in    "$WORKDIR/cert.pem" \
  -name  "$CERT_NAME" \
  -out   "$WORKDIR/identity.p12" \
  -passout pass:"$P12_PASS"

echo "==> Importiere ins login-Keychain …"
security import "$WORKDIR/identity.p12" \
  -k "$KEYCHAIN" \
  -P "$P12_PASS" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productsign

echo "==> Setze ACL für codesign Zugriff (Passwort-Prompt erwartet) …"
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "" "$KEYCHAIN" >/dev/null 2>&1 || true

echo "==> Vertraue Cert für Code-Signing (kann GUI-Prompt auslösen)…"
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$WORKDIR/cert.pem" 2>/dev/null || \
  echo "    (Hinweis: 'add-trusted-cert' erfordert evtl. einmalig Admin-Auth — kann auch manuell via Schlüsselbund-Verwaltung geschehen.)"

PUBLIC_CERT_DEST="$(dirname "$0")/../signing/cert-public.cer"
mkdir -p "$(dirname "$PUBLIC_CERT_DEST")"
openssl x509 -in "$WORKDIR/cert.pem" -outform DER -out "$PUBLIC_CERT_DEST"
echo "==> Public-Cert exportiert nach: $PUBLIC_CERT_DEST"
echo "    Diese Datei wird ins Repo committed und von Mitarbeitern installiert."

echo ""
echo "==> Verifikation:"
security find-identity -v -p codesigning "$KEYCHAIN" | grep -E "(WhisperDictation|^[[:space:]]*[0-9]+\))" || true

echo ""
echo "Fertig. Du kannst jetzt 'scripts/build-release.sh' verwenden."
