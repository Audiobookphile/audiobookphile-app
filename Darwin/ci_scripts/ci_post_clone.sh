#!/bin/sh
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidation -bool YES || true
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES || true
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES || true

# ─────────────────────────────────────────────────────────────────────────────
# Pin Xcode Cloud workflows to a stable Xcode version via App Store Connect API
#
# Set these as Xcode Cloud environment variables (mark ASC_KEY_CONTENT as secret):
#   ASC_KEY_ID        — App Store Connect API Key ID
#   ASC_ISSUER_ID     — App Store Connect Issuer ID
#   ASC_KEY_CONTENT   — Base64-encoded .p8 private key content
#                       (generate with: base64 -i AuthKey_XXXXX.p8 | tr -d '\n')
#   XCODE_PIN_VERSION — Target version name to match (default: "16.4")
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$ASC_KEY_ID" ] && [ -n "$ASC_ISSUER_ID" ] && [ -n "$ASC_KEY_CONTENT" ]; then
  echo "=== Xcode Version Pinning ==="
  XCODE_PIN_VERSION="${XCODE_PIN_VERSION:-16.4}"
  echo "Target version: $XCODE_PIN_VERSION"

  # Decode .p8 key to temp file
  ASC_KEY_FILE=$(mktemp /tmp/asc_key.XXXXXX)
  echo "$ASC_KEY_CONTENT" | base64 --decode > "$ASC_KEY_FILE"
  trap 'rm -f "$ASC_KEY_FILE"' EXIT

  API_BASE="https://api.appstoreconnect.apple.com/v1"

  # Generate JWT for App Store Connect API
  generate_jwt() {
    local now exp header payload signature
    now=$(date +%s)
    exp=$((now + 1200))
    header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$now" "$exp" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$ASC_KEY_FILE" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    printf '%s.%s.%s' "$header" "$payload" "$signature"
  }

  TOKEN=$(generate_jwt)

  # Find the target Xcode version ID
  VERSIONS_JSON=$(curl -sf -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${API_BASE}/ciXcodeVersions?limit=20")
  TARGET_ID=$(echo "$VERSIONS_JSON" | python3 -c "
import json, sys
target = sys.argv[1]
data = json.load(sys.stdin)
for v in data.get('data', []):
    name = v.get('attributes', {}).get('name', '')
    if target.lower() in name.lower():
        print(v['id'])
        break
" "$XCODE_PIN_VERSION" 2>/dev/null)

  if [ -z "$TARGET_ID" ]; then
    echo "⚠️  No Xcode version matching '$XCODE_PIN_VERSION' found. Skipping pin."
    echo "Available versions:"
    echo "$VERSIONS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for v in data.get('data', []):
    print(f'  - {v[\"attributes\"].get(\"name\", \"?\")}')
" 2>/dev/null
  else
    echo "✅ Found Xcode version id=$TARGET_ID"

    # Get all workflows across all products
    PRODUCTS_JSON=$(curl -sf -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${API_BASE}/ciProducts?limit=10")
    PRODUCT_IDS=$(echo "$PRODUCTS_JSON" | python3 -c "
import json, sys
for p in json.load(sys.stdin).get('data', []):
    print(p['id'])
" 2>/dev/null)

    UPDATED=0
    for PID in $PRODUCT_IDS; do
      WORKFLOWS_JSON=$(curl -sf -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "${API_BASE}/ciProducts/$PID/workflows?limit=20")

      echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
for w in json.load(sys.stdin).get('data', []):
    print(w['id'] + ' ' + w.get('attributes', {}).get('name', '?'))
" 2>/dev/null | while read -r WID WNAME; do
        PATCH_BODY=$(python3 -c "
import json
print(json.dumps({
    'data': {
        'type': 'ciWorkflows',
        'id': '$WID',
        'relationships': {
            'xcodeVersion': {
                'data': {
                    'type': 'ciXcodeVersions',
                    'id': '$TARGET_ID'
                }
            }
        }
    }
}))
")
        if curl -sf -X PATCH \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "$PATCH_BODY" \
          "${API_BASE}/ciWorkflows/$WID" > /dev/null 2>&1; then
          echo "  📌 Pinned '$WNAME' → Xcode $XCODE_PIN_VERSION"
        else
          echo "  ⚠️  Failed to pin '$WNAME'"
        fi
      done
    done
    echo "=== Xcode Version Pinning Complete ==="
  fi
else
  echo "=== Xcode version pinning skipped (ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_CONTENT not set) ==="
fi

# Force defaults on xcodebuild and global domains just in case
defaults write com.apple.dt.xcodebuild IDESkipPackagePluginFingerprintValidatation -bool YES || true
defaults write com.apple.dt.xcodebuild IDESkipPackagePluginFingerprintValidation -bool YES || true
defaults write -g IDESkipPackagePluginFingerprintValidatation -bool YES || true
defaults write -g IDESkipPackagePluginFingerprintValidation -bool YES || true
defaults write com.apple.dt.xcodebuild IDESkipMacroFingerprintValidation -bool YES || true
defaults write -g IDESkipMacroFingerprintValidation -bool YES || true

echo "Defaults applied:"
defaults read com.apple.dt.Xcode | grep IDESkip || true


echo "=== Generating Skip.env ==="
# Xcode Cloud provides CI_PRIMARY_REPOSITORY_PATH pointing to the repo root
WORKSPACE_PATH="${CI_PRIMARY_REPOSITORY_PATH:-$(git rev-parse --show-toplevel)}"
ENV_FILE="$WORKSPACE_PATH/Skip.env"

echo "Writing Skip.env to $ENV_FILE"

echo "=== Validating Environment Variables ==="
if [ -z "$NEXT_PUBLIC_SUPABASE_URL" ] || [ "$NEXT_PUBLIC_SUPABASE_URL" = "https://your-supabase-url.supabase.co" ]; then
    echo "❌ ERROR: NEXT_PUBLIC_SUPABASE_URL is not set in Xcode Cloud."
    echo "Please add it to the Xcode Cloud Workflow Environment Variables."
    exit 1
fi

if [ -z "$NEXT_PUBLIC_SUPABASE_ANON_KEY" ] || [ "$NEXT_PUBLIC_SUPABASE_ANON_KEY" = "your_supabase_anon_key" ]; then
    echo "❌ ERROR: NEXT_PUBLIC_SUPABASE_ANON_KEY is not set in Xcode Cloud."
    echo "Please add it to the Xcode Cloud Workflow Environment Variables."
    exit 1
fi
echo "✅ Environment variables validated."

cat << INNER_EOF > "$ENV_FILE"
PRODUCT_NAME = ${SKIP_PRODUCT_NAME:-${PRODUCT_NAME:-Audiobookphile}}
PRODUCT_BUNDLE_IDENTIFIER = ${SKIP_BUNDLE_ID:-${PRODUCT_BUNDLE_IDENTIFIER:-club.foodshare.audiobookphile}}
MARKETING_VERSION = ${SKIP_MARKETING_VERSION:-1.0.1}
CURRENT_PROJECT_VERSION = ${SKIP_BUILD_NUMBER:-${CI_BUILD_NUMBER:-1}}
ANDROID_PACKAGE_NAME = ${SKIP_ANDROID_PACKAGE_NAME:-audiobookphile.module}
TEAM_ID = ${SKIP_TEAM_ID:-${TEAM_ID:-${CI_TEAM_ID}}}
API_SERVER_URL = ${SKIP_API_SERVER_URL:-https://audiobookphile.app/api}
NEXT_PUBLIC_SUPABASE_URL = ${NEXT_PUBLIC_SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY = ${NEXT_PUBLIC_SUPABASE_ANON_KEY}
SENTRY_DSN = ${SENTRY_DSN:-}
INNER_EOF

echo "Skip.env successfully generated!"
