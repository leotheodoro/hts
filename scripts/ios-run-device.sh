#!/bin/sh
# Builds the Debug app, installs it on a connected iPhone and launches it.
# Needs apps/ios/Local.xcconfig with HTS_DEVELOPMENT_TEAM. Optional: DEVICE="Leo's iPhone".
set -eu
cd "$(dirname "$0")/.."

if [ ! -f apps/ios/Local.xcconfig ]; then
  echo "Missing apps/ios/Local.xcconfig. Copy apps/ios/Local.xcconfig.example and set HTS_DEVELOPMENT_TEAM." >&2
  exit 1
fi

json=$(mktemp)
xcrun devicectl list devices --json-output "$json" >/dev/null
device=$(python3 - "$json" "${DEVICE:-}" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
wanted = sys.argv[2]
for d in devices:
    props, hw = d.get("deviceProperties", {}), d.get("hardwareProperties", {})
    if hw.get("platform") != "iOS" or d.get("connectionProperties", {}).get("pairingState") != "paired":
        continue
    if not wanted or props.get("name") == wanted:
        print(d["identifier"]); break
PY
)
rm -f "$json"
if [ -z "$device" ]; then
  echo "No paired iPhone found. Connect it by cable, trust this Mac and enable Developer Mode." >&2
  exit 1
fi

xcodebuild build -project apps/ios/HTS.xcodeproj -scheme HTS -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath apps/ios/build \
  -allowProvisioningUpdates -skipPackagePluginValidation -skipMacroValidation -quiet
app=apps/ios/build/Build/Products/Debug-iphoneos/HTS.app
bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Info.plist")
xcrun devicectl device install app --device "$device" "$app"
xcrun devicectl device process launch --device "$device" "$bundle_id"
