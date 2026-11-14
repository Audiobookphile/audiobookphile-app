#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# distribute.sh
#
# Programmatic End-to-End iOS Distribution using App Store Connect API Token:
# - Archive iOS app with automatic provisioning via ASC API Key
# - Export IPA with App Store Connect distribution profile
# - Upload binary using xcrun altool
# - Poll ingestion & distribute to TestFlight groups
# - Attach to App Store Version & submit for Production review
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

show_help() {
  cat <<EOF
Usage: ./scripts/distribute.sh <command> [options]

Commands:
  archive                 Build and archive the iOS app using ASC API credentials
  export                  Export the archive to a production .ipa package
  upload                  Upload the .ipa to App Store Connect via xcrun altool
  testflight              Poll ingestion and link build to TestFlight beta groups
  production              Poll ingestion, attach to App Store Version, and submit
  all-testflight          Run archive -> export -> upload -> testflight
  all-production          Run archive -> export -> upload -> production
  screenshots             Audit and synchronize screenshots to App Store Version
  status                  Check current builds, TestFlight groups, and versions

Options:
  --group <name>          TestFlight beta group name (default: all groups)
  --whats-new "<text>"    Release notes / What to test
  --version-string <ver>  Version number to create in App Store (e.g. 1.0.1)
  --submit                (Production only) Automatically submit for App Store review

Environment Variables:
  ASC_KEY_ID              App Store Connect API Key ID (10 chars, e.g. 2X9R4HXF34)
  ASC_ISSUER_ID           App Store Connect Issuer ID (UUID)
  ASC_KEY_PATH            Path to AuthKey_<KEY_ID>.p8 (or placed in ~/.appstoreconnect/private_keys/)

Examples:
  ./scripts/distribute.sh all-testflight --whats-new "Bug fixes and audio improvements"
  ./scripts/distribute.sh all-production --version-string 1.0.1 --submit
EOF
}

# ── Parse Command first so help works without env ──
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

COMMAND="$1"
shift

if [ "$COMMAND" = "help" ] || [ "$COMMAND" = "--help" ] || [ "$COMMAND" = "-h" ]; then
  show_help
  exit 0
fi

# ── 1. Validate Environment with Project Defaults ──
export ASC_KEY_ID="${ASC_KEY_ID:-3B28BL42D3}"
export ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de8f-c4a2-47e3-e053-5b8c7c11a4d1}"
export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-DCKVD6LKYV}"

if [ -z "${ASC_KEY_PATH:-}" ]; then
  CANDIDATES=(
    "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
    "$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
    "$APP_DIR/private_keys/AuthKey_${ASC_KEY_ID}.p8"
    "$APP_DIR/AuthKey_${ASC_KEY_ID}.p8"
  )
  for c in "${CANDIDATES[@]}"; do
    if [ -f "$c" ]; then
      ASC_KEY_PATH="$c"
      break
    fi
  done
fi

if [ -z "${ASC_KEY_PATH:-}" ] || [ ! -f "$ASC_KEY_PATH" ]; then
  echo "❌ Error: App Store Connect private key (.p8) not found."
  echo "Place it at ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8 or set ASC_KEY_PATH."
  exit 1
fi
export ASC_KEY_PATH

WORKSPACE="$APP_DIR/Project.xcworkspace"
SCHEME="${SCHEME:-Audiobookphile App}"
BUILD_DIR="$APP_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Audiobookphile.xcarchive"
IPA_DIR="$BUILD_DIR/ipa"
IPA_PATH="$IPA_DIR/Audiobookphile.ipa"
EXPORT_OPTIONS="$APP_DIR/exportOptions-appstore.plist"


BUILD_NUMBER="${BUILD_NUMBER:-}"
get_build_number() {
  if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER=$(python3 "$SCRIPT_DIR/distribute.py" next-build-number 2>/dev/null || echo "1")
  fi
  echo "$BUILD_NUMBER"
}

cmd_archive() {
  echo "📦 Step 1: Archiving $SCHEME..."
  mkdir -p "$BUILD_DIR"

  BUILD_NUMBER=$(get_build_number)
  echo "  Target build number: $BUILD_NUMBER"

  xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-DCKVD6LKYV}" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    SKIP_ZERO=true \
    -skipPackagePluginValidation \
    -skipMacroValidation
  echo "✅ Archive created at $ARCHIVE_PATH"
}

cmd_export() {
  echo "📤 Step 2: Exporting IPA..."
  mkdir -p "$IPA_DIR"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$IPA_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  
  # Find exported ipa if name differs
  ACTUAL_IPA=$(find "$IPA_DIR" -name "*.ipa" -type f | head -1)
  if [ -n "$ACTUAL_IPA" ]; then
    IPA_PATH="$ACTUAL_IPA"
  fi
  echo "✅ Export complete: $IPA_PATH"
}

cmd_upload() {
  echo "🚀 Step 3: Validating and uploading IPA to App Store Connect..."
  ACTUAL_IPA=$(find "$IPA_DIR" -name "*.ipa" -type f 2>/dev/null | head -1)
  if [ -n "$ACTUAL_IPA" ]; then
    IPA_PATH="$ACTUAL_IPA"
  fi

  if [ ! -f "$IPA_PATH" ]; then
    echo "❌ Error: IPA not found at $IPA_PATH. Run './scripts/distribute.sh export' first."
    exit 1
  fi

  xcrun altool --validate-app \
    -f "$IPA_PATH" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
    --p8-file-path "$ASC_KEY_PATH"

  echo "  Validation succeeded. Uploading package..."
  xcrun altool --upload-package "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
    --p8-file-path "$ASC_KEY_PATH"
  echo "✅ IPA uploaded to App Store Connect!"
}


case "$COMMAND" in
  archive)
    cmd_archive
    ;;
  export)
    cmd_export
    ;;
  upload)
    cmd_upload
    ;;
  status)
    python3 "$SCRIPT_DIR/distribute.py" status "$@"
    ;;
  screenshots)
    python3 "$SCRIPT_DIR/distribute.py" screenshots "$@"
    ;;
  testflight)
    python3 "$SCRIPT_DIR/distribute.py" testflight "$@"
    ;;
  production)
    python3 "$SCRIPT_DIR/distribute.py" production "$@"
    ;;
  all-testflight)
    cmd_archive
    cmd_export
    cmd_upload
    python3 "$SCRIPT_DIR/distribute.py" testflight --build-version "$BUILD_NUMBER" "$@"
    ;;
  all-production)
    cmd_archive
    cmd_export
    cmd_upload
    python3 "$SCRIPT_DIR/distribute.py" production --build-version "$BUILD_NUMBER" "$@"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $COMMAND"
    show_help
    exit 1
    ;;
esac
