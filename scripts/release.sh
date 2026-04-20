#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION_FILES=(
  "project.yml"
  "Quixote.xcodeproj/project.pbxproj"
  "site/src/pages/index.astro"
  "site/public/appcast.xml"
)
RELEASE_COMMIT_CREATED=0

cleanup_on_error() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$RELEASE_COMMIT_CREATED" -eq 0 ]; then
    git restore --source=HEAD -- "${VERSION_FILES[@]}" 2>/dev/null || true
  fi
  exit "$exit_code"
}

trap cleanup_on_error ERR

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1"
    exit 1
  fi
}

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
: "${SPARKLE_PRIVATE_KEY_PATH:?ERROR: SPARKLE_PRIVATE_KEY_PATH not set in .env}"

require_cmd gh
require_cmd ruby
require_cmd sed
require_cmd xcodegen
require_cmd xcpretty
require_cmd xcodebuild
require_cmd xcrun
require_cmd hdiutil
require_cmd osascript

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not authenticated. Run: gh auth login"
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

if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
  echo "ERROR: Tag v${VERSION} already exists."
  exit 1
fi

echo ""
echo "▶ Releasing v${VERSION}"
echo ""

BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/Quixote.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_NAME="Quixote-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
REPO_SLUG="c0/quixote"
PAGES_BASE_URL="https://c0.github.io/quixote"
APPCAST_PATH="$REPO_ROOT/site/public/appcast.xml"

if [ ! -f site/package-lock.json ]; then
  echo "ERROR: site/package-lock.json is missing. Run 'cd site && npm install' and commit the lockfile."
  exit 1
fi

SUPUBLICEDKEY="$(ruby -e 'require \"yaml\"; puts YAML.load_file(\"project.yml\").dig(\"targets\", \"Quixote\", \"info\", \"properties\", \"SUPublicEDKey\")')"
if [ -z "$SUPUBLICEDKEY" ] || [ "$SUPUBLICEDKEY" = "REPLACE_WITH_YOUR_PUBLIC_ED_KEY" ]; then
  echo "ERROR: SUPublicEDKey in project.yml is not configured."
  exit 1
fi

if ! grep -q "^## \\[$VERSION\\]" CHANGELOG.md; then
  echo "ERROR: CHANGELOG.md is missing a section for version $VERSION."
  exit 1
fi

if [ ! -f "$SPARKLE_PRIVATE_KEY_PATH" ]; then
  echo "ERROR: SPARKLE_PRIVATE_KEY_PATH does not point to a file: $SPARKLE_PRIVATE_KEY_PATH"
  exit 1
fi

GENERATE_APPCAST="$(find ~/Library/Developer/Xcode/DerivedData -path "*/artifacts/sparkle/Sparkle/bin/generate_appcast" 2>/dev/null | head -1)"
if [ -z "$GENERATE_APPCAST" ]; then
  echo "ERROR: generate_appcast not found in Xcode DerivedData. Build the project in Xcode first to resolve Sparkle package."
  exit 1
fi

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
  -project Quixote.xcodeproj \
  -scheme Quixote \
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

APP_PATH="$EXPORT_DIR/Quixote.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Exported app not found at $APP_PATH"
  exit 1
fi

# ── 6. Create DMG ────────────────────────────────────────────────────────────

echo "▶ Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_TMP="$BUILD_DIR/Quixote-tmp.dmg"
rm -rf "$DMG_STAGING" "$DMG_TMP"
mkdir -p "$DMG_STAGING"

ditto "$APP_PATH" "$DMG_STAGING/Quixote.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -srcfolder "$DMG_STAGING" \
  -volname "Quixote" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,b=16" \
  -format UDRW \
  -size 80m \
  "$DMG_TMP"

MOUNT_DIR="/Volumes/Quixote"
hdiutil detach -force "$MOUNT_DIR" 2>/dev/null || true
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$DMG_TMP"

osascript <<EOF
tell application "Finder"
  tell disk "Quixote"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {400, 100, 920, 440}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "Quixote.app" of container window to {130, 170}
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

# ── 8. Generate appcast ──────────────────────────────────────────────────────

echo "▶ Generating appcast..."
APPCAST_DIR="$REPO_ROOT/site/public"
mkdir -p "$APPCAST_DIR"
find "$BUILD_DIR" -maxdepth 1 -name "*.dmg" ! -name "$DMG_NAME" -delete

"$GENERATE_APPCAST" \
  --ed-key-file "$SPARKLE_PRIVATE_KEY_PATH" \
  --download-url-prefix "https://github.com/${REPO_SLUG}/releases/download/v${VERSION}/" \
  --link "https://github.com/${REPO_SLUG}" \
  -o "$APPCAST_PATH" \
  "$BUILD_DIR"

git add "$APPCAST_PATH" project.yml Quixote.xcodeproj/project.pbxproj site/src/pages/index.astro
git commit -m "chore: update appcast for v${VERSION}"
RELEASE_COMMIT_CREATED=1

# ── 9. Tag and publish release ───────────────────────────────────────────────

echo "▶ Pushing release commit to main..."
git push origin main

echo "▶ Tagging v${VERSION}..."
git tag "v${VERSION}"
git push origin "v${VERSION}"

echo "▶ Creating GitHub Release..."

NOTES="$(awk "/^## \[${VERSION}\]/{found=1; next} found && /^## \[/{exit} found{print}" CHANGELOG.md)"

gh release create "v${VERSION}" "$DMG_PATH" \
  --title "v${VERSION}" \
  --notes "$NOTES"

echo ""
echo "✓ Released v${VERSION}"
echo "  DMG:     $DMG_PATH"
echo "  Tag:     v${VERSION}"
echo "  Appcast: ${PAGES_BASE_URL}/appcast.xml"
