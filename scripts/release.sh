#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ── 1. Load .env and validate environment ────────────────────────────────────

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example and fill in your credentials."
  exit 1
fi
# shellcheck source=/dev/null
source .env

: "${APPLE_TEAM_ID:?ERROR: APPLE_TEAM_ID not set in .env}"
: "${APPLE_ID:?ERROR: APPLE_ID not set in .env}"
: "${SIGNING_IDENTITY_NAME:?ERROR: SIGNING_IDENTITY_NAME not set in .env}"

# Verify gh CLI is available
if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install with: brew install gh && gh auth login"
  exit 1
fi

# Branch must be main
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "ERROR: Must be on main branch (currently on '$CURRENT_BRANCH')."
  exit 1
fi

# Working tree must be clean
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Verify APPLE_APP_SPECIFIC_PASSWORD is set
if [ -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
  echo "ERROR: APPLE_APP_SPECIFIC_PASSWORD is not set."
  echo "  Add it to .env: APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx"
  echo "  Generate one at: appleid.apple.com → Sign-In and Security → App-Specific Passwords"
  exit 1
fi
AC_PASSWORD="$APPLE_APP_SPECIFIC_PASSWORD"

# ── 2. Determine version ─────────────────────────────────────────────────────

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

echo ""
echo "▶ Releasing v${VERSION}"
echo ""

BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/QuixoteSwift.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_NAME="QuixoteSwift-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_PATH"

# ── 3. Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION + xcodegen generate ──

echo "▶ Bumping MARKETING_VERSION to ${VERSION}..."
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml

CURRENT_BUILD="$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | grep -o '"[0-9]*"' | tr -d '"')"
NEXT_BUILD="$((CURRENT_BUILD + 1))"
echo "▶ Bumping CURRENT_PROJECT_VERSION to ${NEXT_BUILD}..."
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"${NEXT_BUILD}\"/" project.yml

# Update APP_VERSION in site
sed -i '' "s/const APP_VERSION = \"[^\"]*\"/const APP_VERSION = \"${VERSION}\"/" site/src/pages/index.astro

echo "▶ Generating Xcode project..."
xcodegen generate

# ── 4. xcodebuild archive ────────────────────────────────────────────────────

echo "▶ Archiving..."
xcodebuild archive \
  -project QuixoteSwift.xcodeproj \
  -scheme QuixoteSwift \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY_NAME" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  | xcpretty 2>/dev/null || true

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "ERROR: Archive not found at $ARCHIVE_PATH"
  exit 1
fi

# ── 5. xcodebuild -exportArchive ─────────────────────────────────────────────

echo "▶ Exporting archive..."
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
sed "s/\${APPLE_TEAM_ID}/$APPLE_TEAM_ID/g" ExportOptions.plist > "$EXPORT_OPTIONS"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP_PATH="$EXPORT_DIR/Quixote Swift.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Exported app not found at $APP_PATH"
  exit 1
fi

# ── 6. Create DMG ────────────────────────────────────────────────────────────

echo "▶ Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_TMP="$BUILD_DIR/QuixoteSwift-tmp.dmg"
rm -rf "$DMG_STAGING" "$DMG_TMP"
mkdir -p "$DMG_STAGING"

ditto "$APP_PATH" "$DMG_STAGING/Quixote Swift.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -srcfolder "$DMG_STAGING" \
  -volname "QuixoteSwift" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,b=16" \
  -format UDRW \
  -size 80m \
  "$DMG_TMP"

MOUNT_DIR="/Volumes/QuixoteSwift"
hdiutil detach -force "$MOUNT_DIR" 2>/dev/null || true
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$DMG_TMP"

osascript <<EOF
tell application "Finder"
  tell disk "QuixoteSwift"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {400, 100, 920, 440}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "Quixote Swift.app" of container window to {130, 170}
    set position of item "Applications" of container window to {390, 170}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
EOF

hdiutil detach -force "$MOUNT_DIR"
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$DMG_TMP"
rm -rf "$DMG_STAGING"

echo "  DMG: $DMG_PATH"

# ── 7. Notarize and staple ───────────────────────────────────────────────────

echo "▶ Notarizing (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$AC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

echo "▶ Stapling..."
xcrun stapler staple "$DMG_PATH"

# ── 8. Tag and push ──────────────────────────────────────────────────────────

echo "▶ Tagging v${VERSION}..."
git tag "v${VERSION}"
git push origin "v${VERSION}"

# ── 9. Generate appcast ──────────────────────────────────────────────────────

echo "▶ Generating appcast..."
APPCAST_DIR="$REPO_ROOT/site/public"
mkdir -p "$APPCAST_DIR"
find "$BUILD_DIR" -maxdepth 1 -name "*.dmg" ! -name "$DMG_NAME" -delete

GENERATE_APPCAST="$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin/generate_appcast" 2>/dev/null | head -1)"
if [ -z "$GENERATE_APPCAST" ]; then
  echo "ERROR: generate_appcast not found in Xcode DerivedData. Build the project in Xcode first to resolve Sparkle package."
  exit 1
fi

"$GENERATE_APPCAST" \
  --download-url-prefix "https://github.com/c0/quixote-swift/releases/download/v${VERSION}/" \
  -o "$APPCAST_DIR/appcast.xml" \
  "$BUILD_DIR"

git add "$APPCAST_DIR/appcast.xml" project.yml QuixoteSwift.xcodeproj/project.pbxproj site/src/pages/index.astro
git commit -m "chore: update appcast for v${VERSION}"
git push origin main

# ── 10. Create GitHub Release ────────────────────────────────────────────────

echo "▶ Creating GitHub Release..."

NOTES="$(awk "/^## \[${VERSION}\]/{found=1; next} found && /^## \[/{exit} found{print}" CHANGELOG.md)"

gh release create "v${VERSION}" "$DMG_PATH" \
  --title "v${VERSION}" \
  --notes "$NOTES"

echo ""
echo "✓ Released v${VERSION}"
echo "  DMG:     $DMG_PATH"
echo "  Tag:     v${VERSION}"
echo "  Appcast: https://c0.github.io/quixote-swift/appcast.xml"
