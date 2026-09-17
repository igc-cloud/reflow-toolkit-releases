#!/bin/sh
# Reflow Toolkit installer for macOS.
#
# Why this exists rather than "download the .dmg from Releases": the app is not signed with
# an Apple Developer ID, so Gatekeeper refuses anything the browser downloads. That refusal
# comes from an extended attribute (com.apple.quarantine) the browser attaches, not from the
# binary - and curl does not attach it. So a terminal install has no warning to dismiss,
# while a browser download has one per machine.
#
# It also verifies what it downloaded. See "Verification" below for what that does and does
# not protect against.

set -eu

REPO="igc-cloud/reflow-toolkit-releases"
APP_NAME="Reflow Toolkit"
INSTALL_DIR="/Applications"

red() { printf '\033[31m%s\033[0m\n' "$1" >&2; }
dim() { printf '\033[2m%s\033[0m\n' "$1"; }
say() { printf '%s\n' "$1"; }

fail() { red "$1"; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "This installer is for macOS. On Windows use install.ps1."

case "$(uname -m)" in
    arm64) ARCH="aarch64" ;;
    x86_64) ARCH="x64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

say "Finding the latest release..."
TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$TAG" ] || fail "Could not read the latest release. Is the network up?"

VERSION="${TAG#v}"
BUNDLE="Reflow.Toolkit_${VERSION}_${ARCH}.app.tar.gz"
BASE="https://github.com/$REPO/releases/download/$TAG"

say "Downloading $APP_NAME $VERSION ($ARCH)..."
curl -fsSL -o "$TMP/$BUNDLE" "$BASE/$BUNDLE" || fail "Download failed: $BASE/$BUNDLE"

# Verification.
#
# SHA256SUMS.txt travels with the release and is what catches a truncated or corrupted
# download. It is NOT a defence against a malicious release: it arrives from the same place
# as the binary, so anyone who could tamper with one could tamper with both.
#
# The real signature is the minisign one (.sig), checked against the public key baked into
# the app. That is what the auto-updater verifies on every update. Verifying it here needs
# the `minisign` binary, so this script checks it when present and says so when absent
# rather than pretending the SHA256 is equivalent.
if curl -fsSL -o "$TMP/SHA256SUMS.txt" "$BASE/SHA256SUMS.txt" 2>/dev/null; then
    say "Verifying checksum..."
    ( cd "$TMP" && grep " $BUNDLE\$" SHA256SUMS.txt | shasum -a 256 -c - >/dev/null ) \
        || fail "Checksum mismatch. The download is corrupt or has been tampered with; nothing was installed."
else
    dim "No checksum file in this release; skipping checksum verification."
fi

if command -v minisign >/dev/null 2>&1; then
    if curl -fsSL -o "$TMP/$BUNDLE.sig" "$BASE/$BUNDLE.sig" 2>/dev/null \
        && curl -fsSL -o "$TMP/pubkey" "$BASE/minisign.pub" 2>/dev/null; then
        say "Verifying signature..."
        minisign -Vm "$TMP/$BUNDLE" -p "$TMP/pubkey" >/dev/null 2>&1 \
            || fail "Signature verification failed. Nothing was installed."
    fi
else
    dim "minisign not installed; signature not verified (brew install minisign for a stronger check)."
fi

if pgrep -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1; then
    say "Quitting the running app..."
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    sleep 2
fi

say "Installing to $INSTALL_DIR..."
tar -xzf "$TMP/$BUNDLE" -C "$TMP" || fail "Could not unpack the download."
[ -d "$TMP/$APP_NAME.app" ] || fail "The download did not contain $APP_NAME.app."

rm -rf "${INSTALL_DIR:?}/$APP_NAME.app"
cp -R "$TMP/$APP_NAME.app" "$INSTALL_DIR/" \
    || fail "Could not write to $INSTALL_DIR. Try again with sudo, or install to ~/Applications."

# Belt and braces: curl does not set the quarantine attribute, but a file that reached this
# script by some other route might carry one, and a quarantined app fails to open with a
# message that says nothing useful.
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

say ""
say "$APP_NAME $VERSION installed."
dim "Open it from Launchpad, or run: open -a \"$APP_NAME\""
dim "It updates itself from here on - no need to run this again."
