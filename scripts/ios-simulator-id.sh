#!/bin/sh
# Prints the UDID of the first available simulator with the given name (default: iPhone 17 Pro Max).
# xcodebuild's `name=` destination defaults to the latest OS, which may not ship that device.
name="${1:-iPhone 17 Pro Max}"
id=$(xcrun simctl list devices available | grep -F "    $name (" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}')
if [ -z "$id" ]; then
  echo "No available simulator named \"$name\". Install a runtime with: xcodebuild -downloadPlatform iOS" >&2
  exit 1
fi
echo "$id"
