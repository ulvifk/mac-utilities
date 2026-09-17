#!/bin/bash
# One-time: creates a self-signed code-signing certificate "mac-utilities" in the login keychain,
# so rebuilt apps keep their Accessibility permission.
set -euo pipefail
DIR=$(mktemp -d)
cd "$DIR"

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout key.pem -out cert.pem \
  -subj "/CN=mac-utilities" -addext "keyUsage=digitalSignature" -addext "extendedKeyUsage=codeSigning"
openssl pkcs12 -export -inkey key.pem -in cert.pem -out cert.p12 -passout pass:x -name mac-utilities -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

security import cert.p12 -k ~/Library/Keychains/login.keychain-db -P x -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db cert.pem

rm -rf "$DIR"
security find-identity -v -p codesigning
