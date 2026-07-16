#!/usr/bin/env bash
# Simulates a message push notification landing on the simulator via
# `xcrun simctl push`, to validate ONLY the on-device presentation/tap
# handling (the foreground banner + tap-to-open behavior wired up in
# App/Sources/AppDelegate.swift's UNUserNotificationCenterDelegate methods).
# It does NOT exercise the server -> APNs path at all (that needs the
# deployed notify-message edge function plus a real device with a real APNs
# token — see docs/BACKEND.md "Message push notifications").
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_ID="${1:-562AA1B2-9625-48E3-B064-BB2B386C1131}"
BUNDLE_ID="com.ascend.Ascend"
PAYLOAD="$ROOT_DIR/Scripts/message-push-payload.json"

xcrun simctl push "$DEVICE_ID" "$BUNDLE_ID" "$PAYLOAD"
