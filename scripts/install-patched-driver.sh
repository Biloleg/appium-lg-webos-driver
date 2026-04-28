#!/usr/bin/env bash
# install-patched-driver.sh
# 1. Installs appium-lg-webos-driver globally via npm
# 2. Applies the improvements patch
# 3. Registers the patched driver with Appium
#
# Usage: bash scripts/install-patched-driver.sh
# Requires: patch, npm, appium

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/webos-driver-improvements.patch"

# ── 1. Locate npm global prefix ──────────────────────────────────────────────
NPM_PREFIX="$(npm config get prefix)"
DRIVER_DIR="$NPM_PREFIX/lib/node_modules/appium-lg-webos-driver"

echo "══════════════════════════════════════════════════"
echo " LG WebOS Driver – patched install"
echo "══════════════════════════════════════════════════"

# ── 2. Check patch file exists ────────────────────────────────────────────────
if [ ! -f "$PATCH_FILE" ]; then
  echo "✖ Patch file not found: $PATCH_FILE"
  echo "  Run  bash scripts/generate-patch.sh  first."
  exit 1
fi

# ── 3. Install the published driver globally ─────────────────────────────────
echo ""
echo "→ Step 1/3 – Installing appium-lg-webos-driver from npm..."
npm install -g appium-lg-webos-driver
echo "✔ Installed to: $DRIVER_DIR"

# ── 4. Apply patch ───────────────────────────────────────────────────────────
echo ""
echo "→ Step 2/3 – Applying patch..."
pushd "$DRIVER_DIR" > /dev/null

# Dry-run first to detect any issues
if ! patch --dry-run -p1 --forward < "$PATCH_FILE" > /dev/null 2>&1; then
  echo "  ⚠ Dry-run check failed – attempting to apply anyway (patch may be partially applied)..."
fi

patch -p1 --forward --reject-file=/tmp/webos-driver.rej < "$PATCH_FILE" && {
  echo "✔ Patch applied successfully"
} || {
  EXIT=$?
  if [ $EXIT -eq 1 ] && [ -f /tmp/webos-driver.rej ]; then
    echo "✖ Some hunks failed to apply. Rejected hunks saved to /tmp/webos-driver.rej"
    cat /tmp/webos-driver.rej
    popd > /dev/null
    exit 1
  fi
}

# Fix version in package.json to 0.6.0
sed -i '' 's/"version": "0.5.0"/"version": "0.6.0"/' "$DRIVER_DIR/package.json" 2>/dev/null || \
  sed -i 's/"version": "0.5.0"/"version": "0.6.0"/' "$DRIVER_DIR/package.json"

echo "✔ Version bumped to 0.6.0 in $DRIVER_DIR/package.json"

popd > /dev/null

# ── 5. Register with Appium ──────────────────────────────────────────────────
echo ""
echo "→ Step 3/3 – Registering driver with Appium..."
appium driver install --source=local "$DRIVER_DIR"
echo ""
echo "══════════════════════════════════════════════════"
echo "✔ Done! appium-lg-webos-driver (patched) is ready."
echo "══════════════════════════════════════════════════"
appium driver list --installed 2>/dev/null | grep -i webos || true

