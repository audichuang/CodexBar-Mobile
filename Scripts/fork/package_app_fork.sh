#!/usr/bin/env bash
# Fork-owned packaging hooks, sourced by Scripts/package_app.sh.
# Each function is called from one declared hook line in package_app.sh.
# Expects package_app.sh variables: ROOT, CONF, LOWER_CONF, SIGNING_MODE,
# BUNDLE_ID, INCLUDE_SHARED_ENTITLEMENTS, and the patch_keyboard_shortcuts function.

# Validate the CloudKit provisioning profile before compiling anything.
# Release + real-signed builds claim CloudKit and push entitlements, so the
# embedded profile must authorize them (app id, team, aps-environment=production,
# CloudKit, iCloud container, unexpired). Fail loud here instead of shipping a
# bundle that AMFI rejects or that never receives CloudKit change pushes.
fork_validate_cloudkit_profile() {
PROVISION_PROFILE="$ROOT/Provisioning/CodexBar_Dev.provisionprofile"
if [[ "${CONF}" == "release" && "${SIGNING_MODE:-}" != "adhoc" ]]; then
  if [[ ! -f "$PROVISION_PROFILE" ]]; then
    echo "FATAL: provisioning profile not found at $PROVISION_PROFILE" >&2
    echo "" >&2
    echo "  This file is gitignored and local-only. In a worktree or fresh" >&2
    echo "  checkout, copy it from the main repo:" >&2
    echo "    cp -R <main-repo>/Provisioning $ROOT/" >&2
    echo "" >&2
    echo "  Without it the bundle ships missing Contents/embedded.provisionprofile" >&2
    echo "  and AMFI rejects the binary at launch (POSIX 163), even though" >&2
    echo "  codesign / spctl / notarization / stapler all pass." >&2
    echo "  Enable Push Notifications on the App ID and regenerate the Developer ID profile." >&2
    exit 1
  fi
  python3 "$ROOT/Scripts/validate_cloudkit_profile.py" "$PROVISION_PROFILE" \
    "${APP_TEAM_ID:-37HFR5V2JJ}.com.audichuang.codexbar"
fi
}

# Always resolve before compiling, and from a clean checkout: a restored CI cache
# can hold an older, already-patched KeyboardShortcuts. Without the reset, the
# patch marker would skip patching and `swift build` would then move the checkout
# to the new pin unpatched. Resolving (instead of a bootstrap `swift build`) only
# materializes .build/checkouts, so the patch lands before the first compile.
fork_prepare_keyboard_shortcuts() {
KEYBOARD_SHORTCUTS_UTIL="$ROOT/.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Utilities.swift"
KEYBOARD_SHORTCUTS_CHECKOUT="$ROOT/.build/checkouts/KeyboardShortcuts"
if [[ -d "$KEYBOARD_SHORTCUTS_CHECKOUT/.git" || -f "$KEYBOARD_SHORTCUTS_CHECKOUT/.git" ]]; then
  git -C "$KEYBOARD_SHORTCUTS_CHECKOUT" checkout -q -- . 2>/dev/null || true
fi
swift package resolve
if [[ ! -f "$KEYBOARD_SHORTCUTS_UTIL" ]]; then
  echo "ERROR: swift package resolve did not produce $KEYBOARD_SHORTCUTS_UTIL" >&2
  exit 1
fi
# Idempotent: skips a checkout that already carries the keyboardShortcutsSafeBundle patch.
patch_keyboard_shortcuts
if ! grep -q "keyboardShortcutsSafeBundle" "$KEYBOARD_SHORTCUTS_UTIL"; then
  echo "ERROR: KeyboardShortcuts is not patched (keyboardShortcutsSafeBundle missing in $KEYBOARD_SHORTCUTS_UTIL)" >&2
  exit 1
fi
}

# CloudKit change pushes need the macOS push entitlement; only release identity
# builds embed a profile validated to authorize it. Prints the plist fragment
# (empty when not applicable).
fork_aps_entitlement_keys() {
  if [[ "$LOWER_CONF" == "release" && "$INCLUDE_SHARED_ENTITLEMENTS" == "1" && "$BUNDLE_ID" != *".debug"* ]]; then
    printf '%s\n' "    <key>com.apple.developer.aps-environment</key>
    <string>production</string>"
  fi
}
