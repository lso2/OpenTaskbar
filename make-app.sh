#!/bin/bash
# make-app.sh
# Builds OpenTaskbar.app from the Swift package, assembles the bundle and signs it with Hardened Runtime.
# Exists so one command produces a runnable bundle; the signature identity decides whether grants survive rebuilds.
# Defines: no functions
# Notes: docs/notes/app/make-app.sh.md
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

swift build -c release

app="$here/build/OpenTaskbar.app"
rm -rf "$here/build"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/icons"

cp "$here/.build/release/OpenTaskbar" "$app/Contents/MacOS/OpenTaskbar"
cp "$here/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$here/../hammerspoon/icons/"*.png "$app/Contents/Resources/icons/"
mkdir -p "$app/Contents/Frameworks"
ditto "$here/.build/release/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"

# A Developer ID identity when one exists, then the local development identity, then ad hoc.
identity="${OPENTASKBAR_IDENTITY:-}"
if [ -z "$identity" ]; then
    identity="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi
dev_keychain="$HOME/Library/Keychains/opentaskbar-dev.keychain-db"
if [ -z "$identity" ] && [ -f "$dev_keychain" ]; then
    security unlock-keychain -p "$(cat "$HOME/.config/opentaskbar-dev/keychain-pass")" "$dev_keychain"
    identity="OpenTaskbar Development"
fi
identity="${identity:--}"

# Notarization needs a secure timestamp on every signature; release.sh sets OPENTASKBAR_TIMESTAMP=1.
timestamp="--timestamp=none"
[ "${OPENTASKBAR_TIMESTAMP:-0}" = "1" ] && timestamp="--timestamp"

# Sparkle's helpers are signed inside out before the framework, and the framework before the app.
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --options runtime $timestamp --sign "$identity" "$sparkle/XPCServices/Installer.xpc"
codesign --force --options runtime $timestamp --preserve-metadata=entitlements --sign "$identity" "$sparkle/XPCServices/Downloader.xpc"
codesign --force --options runtime $timestamp --sign "$identity" "$sparkle/Autoupdate"
codesign --force --options runtime $timestamp --sign "$identity" "$sparkle/Updater.app"
codesign --force --options runtime $timestamp --sign "$identity" "$app/Contents/Frameworks/Sparkle.framework"

# A Developer ID signature gives the app and Sparkle one Team ID. The local identity and ad hoc
# signatures carry none, so library validation would refuse the embedded framework without this.
entitlements="$here/Resources/OpenTaskbar.entitlements"
case "$identity" in
    "Developer ID Application"*) ;;
    *) entitlements="$here/Resources/OpenTaskbar-development.entitlements" ;;
esac

codesign --force --options runtime $timestamp \
    --entitlements "$entitlements" \
    --sign "$identity" "$app"

echo "built $app"
echo "signed with: $identity"
