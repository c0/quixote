#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="APP_NAME"

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example and fill in your credentials."
  exit 1
fi

# shellcheck source=/dev/null
source .env

: "${APPLE_TEAM_ID:?ERROR: APPLE_TEAM_ID not set in .env}"
: "${SIGNING_IDENTITY_NAME:?ERROR: SIGNING_IDENTITY_NAME not set in .env}"

for tool in xcodegen xcpretty xcrun; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool '$tool' is not installed."
    exit 1
  fi
done

if [ -n "${1:-}" ]; then
  VERSION="$1"
else
  LAST_TAG="$(git tag -l 'v*' | sort -V | tail -1)"
  if [ -n "$LAST_TAG" ]; then
    LAST_VERSION="${LAST_TAG#v}"
    IFS='.' read -r MAJOR MINOR PATCH <<< "$LAST_VERSION"
    SUGGESTED="$MAJOR.$MINOR.$((PATCH + 1))"
    read -rp "Version to release [${SUGGESTED}]: " VERSION
    VERSION="${VERSION:-$SUGGESTED}"
  else
    read -rp "Version to release: " VERSION
  fi
fi

if [ -z "$VERSION" ]; then
  echo "ERROR: No version specified."
  exit 1
fi

BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/${APP_NAME}.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml

CURRENT_BUILD="$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | grep -o '"[0-9]*"' | tr -d '"')"
NEXT_BUILD="$((CURRENT_BUILD + 1))"
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"${NEXT_BUILD}\"/" project.yml

xcodegen generate

xcodebuild archive \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY_NAME" \
  | xcpretty

EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
sed "s/\${APPLE_TEAM_ID}/$APPLE_TEAM_ID/g" ExportOptions.plist > "$EXPORT_OPTIONS"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "Release archive exported to: $EXPORT_DIR"
echo "Next step: upload the exported build to App Store Connect or TestFlight."
