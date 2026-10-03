#!/bin/bash
set -euo pipefail

IPA="${1:-}"
EXPECTED_BUNDLE_ID="${2:-${BUNDLE_ID:-app.KanadeDX}}"
EXPECTED_TEAM_ID="${3:-${TEAM_ID:-}}"

fail=0
TMP="$(mktemp -d "${TMPDIR:-/tmp}/kdx-ipa-XXXXXX")"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

pass(){ echo "PASS: $*"; }
fail(){ echo "FAIL: $*" >&2; fail=1; }

[[ -n "$IPA" ]] || { echo "Usage: $0 path/to/KanadeDX.ipa [bundle-id] [team-id]" >&2; exit 2; }
[[ -f "$IPA" ]] || { echo "IPA not found: $IPA" >&2; exit 2; }
command -v codesign >/dev/null || { echo "codesign not found (run on macOS/Xcode)." >&2; exit 2; }
command -v security >/dev/null || { echo "security command not found (run on macOS)." >&2; exit 2; }
command -v /usr/libexec/PlistBuddy >/dev/null || { echo "PlistBuddy not found." >&2; exit 2; }

unzip -q "$IPA" -d "$TMP/unzip"
APP_COUNT="$(find "$TMP/unzip/Payload" -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')"
[[ "$APP_COUNT" == "1" ]] || { fail "IPA must contain exactly one .app (found $APP_COUNT)"; exit 1; }
APP="$(find "$TMP/unzip/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
PLIST="$APP/Info.plist"
PROFILE="$APP/embedded.mobileprovision"

[[ -f "$PLIST" ]] || { fail "Info.plist missing"; exit 1; }
[[ -f "$PROFILE" ]] || fail "embedded.mobileprovision missing"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null || true)"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] && pass "Bundle ID = $BUNDLE_ID" || fail "Bundle ID = '$BUNDLE_ID' (expected '$EXPECTED_BUNDLE_ID')"

USAGE="$(/usr/libexec/PlistBuddy -c 'Print :NFCReaderUsageDescription' "$PLIST" 2>/dev/null || true)"
[[ -n "$USAGE" ]] && pass "NFCReaderUsageDescription present" || fail "NFCReaderUsageDescription missing"

echo "-- codesign --"
if codesign --verify --deep --strict --verbose=2 "$APP" >/tmp/kdx_codesign_verify.txt 2>&1; then
  pass "codesign verification"
else
  cat /tmp/kdx_codesign_verify.txt >&2
  fail "codesign verification"
fi

SIGNED_INFO="$(codesign -dvv "$APP" 2>&1 || true)"
SIGNED_ID="$(printf '%s\n' "$SIGNED_INFO" | awk -F= '/^Identifier=/{print $2; exit}')"
SIGNED_TEAM="$(printf '%s\n' "$SIGNED_INFO" | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[[ "$SIGNED_ID" == "$EXPECTED_BUNDLE_ID" ]] && pass "Signed identifier = $SIGNED_ID" || fail "Signed identifier = '$SIGNED_ID'"
if [[ -n "$EXPECTED_TEAM_ID" ]]; then
  [[ "$SIGNED_TEAM" == "$EXPECTED_TEAM_ID" ]] && pass "Signed TeamIdentifier = $SIGNED_TEAM" || fail "Signed TeamIdentifier = '$SIGNED_TEAM' (expected '$EXPECTED_TEAM_ID')"
else
  [[ -n "$SIGNED_TEAM" ]] && pass "Signed TeamIdentifier = $SIGNED_TEAM" || fail "Signed TeamIdentifier missing"
fi

SIGNED_ENT="$TMP/signed-entitlements.plist"
NFC0=""
if codesign -d --entitlements :- "$APP" > "$SIGNED_ENT" 2>/dev/null && /usr/libexec/PlistBuddy -c 'Print :com.apple.developer.nfc.readersession.formats:0' "$SIGNED_ENT" >/dev/null 2>&1; then
  NFC0="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.nfc.readersession.formats:0' "$SIGNED_ENT" 2>/dev/null || true)"
  [[ "$NFC0" == "TAG" ]] && pass "Signed NFC entitlement contains TAG" || fail "Signed NFC entitlement does not contain TAG"
else
  fail "Signed NFC entitlement missing"
fi

security cms -D -i "$PROFILE" -o "$TMP/profile.plist" >/dev/null 2>&1 || { fail "Cannot decode provisioning profile"; exit 1; }
PROFILE_APPID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$TMP/profile.plist" 2>/dev/null || true)"
PROFILE_TEAM="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' "$TMP/profile.plist" 2>/dev/null || true)"
PROFILE_NFC="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.nfc.readersession.formats:0' "$TMP/profile.plist" 2>/dev/null || true)"

[[ "$PROFILE_APPID" == "$SIGNED_TEAM.$EXPECTED_BUNDLE_ID" ]] && pass "Provisioning application-identifier matches TeamID.BundleID" || fail "Provisioning application-identifier = '$PROFILE_APPID'"
[[ "$PROFILE_TEAM" == "$SIGNED_TEAM" ]] && pass "Provisioning Team ID matches signed Team ID" || fail "Provisioning Team ID = '$PROFILE_TEAM'"
[[ "$PROFILE_NFC" == "TAG" ]] && pass "Provisioning profile NFC entitlement contains TAG" || fail "Provisioning profile NFC TAG entitlement missing"

EXPIRY="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$TMP/profile.plist" 2>/dev/null || true)"
if [[ -n "$EXPIRY" ]]; then
  if python3 - "$EXPIRY" <<'PY'
import sys
from datetime import datetime, timezone
s=sys.argv[1].replace('Z','+00:00')
try:
    d=datetime.fromisoformat(s)
    if d.tzinfo is None: d=d.replace(tzinfo=timezone.utc)
    raise SystemExit(0 if d > datetime.now(timezone.utc) else 1)
except Exception:
    raise SystemExit(1)
PY
  then
    pass "Provisioning profile is not expired ($EXPIRY)"
  else
    fail "Provisioning profile is expired ($EXPIRY)"
  fi
else
  fail "Provisioning profile expiration missing"
fi

# Strict consistency check: signed NFC entitlement must be TAG and profile must also permit TAG.
if [[ "$NFC0" == "TAG" && "$PROFILE_NFC" == "TAG" ]]; then
  pass "Signed/profile NFC entitlement consistency"
else
  fail "Signed/profile NFC entitlement mismatch"
fi

echo
echo "=== IPA verification summary ==="
if [[ "$fail" -eq 0 ]]; then
  echo "PASS: KanadeDX IPA passed bundle, NFC, provisioning, and codesign checks."
  exit 0
else
  echo "FAIL: KanadeDX IPA failed one or more checks." >&2
  exit 1
fi
