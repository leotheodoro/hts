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
# Prints "<CoreDevice id> <UDID>": devicectl wants the first, xcodebuild the second.
ids=$(python3 - "$json" "${DEVICE:-}" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
wanted = sys.argv[2]
for d in devices:
    props, hw = d.get("deviceProperties", {}), d.get("hardwareProperties", {})
    if hw.get("platform") != "iOS" or hw.get("reality") != "physical" \
            or d.get("connectionProperties", {}).get("pairingState") != "paired":
        continue
    if not wanted or props.get("name") == wanted:
        print(d["identifier"], hw.get("udid", "")); break
PY
)
rm -f "$json"
device=${ids%% *}
udid=${ids#* }
if [ -z "$ids" ]; then
  echo "No paired iPhone found. Connect it by cable, trust this Mac and enable Developer Mode." >&2
  exit 1
fi

xcodebuild build -project apps/ios/HTS.xcodeproj -scheme HTS -configuration Debug \
  -destination "platform=iOS,id=$udid" -derivedDataPath apps/ios/build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -skipPackagePluginValidation -skipMacroValidation -quiet
app=apps/ios/build/Build/Products/Debug-iphoneos/HTS.app
bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Info.plist")
xcrun devicectl device install app --device "$device" "$app"
if ! xcrun devicectl device process launch --device "$device" "$bundle_id"; then
  echo "" >&2
  echo "Installed, but iOS refused to launch it. On the first install with a Personal Team, trust the developer on" >&2
  echo "the iPhone: Settings > General > VPN & Device Management > your Apple ID > Trust. Then run this again." >&2
  exit 1
fi
