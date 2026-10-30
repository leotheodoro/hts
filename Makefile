IOS_DIR := apps/ios
KIT_DIR := $(IOS_DIR)/HTSKit
PROJECT := $(IOS_DIR)/HTS.xcodeproj
SIMULATOR ?= iPhone 17 Pro Max
SIMULATOR_ID = $(shell scripts/ios-simulator-id.sh "$(SIMULATOR)")
DESTINATION = platform=iOS Simulator,id=$(SIMULATOR_ID)
# Simulator builds are signed ad hoc ("-"): without a signature the app has no entitlements and the Keychain,
# where the login session lives, refuses it (errSecMissingEntitlement, docs/decisions/0031).
XCODEBUILD_FLAGS = -project $(PROJECT) -scheme HTS -destination "$(DESTINATION)" \
	-skipPackagePluginValidation -skipMacroValidation CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
	DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=

.PHONY: ios-generate ios-test ios-kit-test ios-kit-test-sim ios-app-test ios-build ios-format ios-lint ios-device ios-team-id ios-mac-host

ios-generate:
	cd $(IOS_DIR) && xcodegen generate

ios-kit-test:
	cd $(KIT_DIR) && swift test

# HTSKit tests on the iOS simulator instead of the host Mac: CI runners may have an older macOS than the
# package's minimum (macOS 26).
ios-kit-test-sim:
	cd $(KIT_DIR) && xcodebuild test -scheme HTSKit-Package -destination "$(DESTINATION)" \
		-skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO -quiet

ios-app-test: ios-generate
	xcodebuild test $(XCODEBUILD_FLAGS)

ios-test: ios-kit-test ios-app-test

ios-build: ios-generate
	xcodebuild build $(XCODEBUILD_FLAGS)

ios-format:
	swift format format --in-place --recursive --configuration $(IOS_DIR)/.swift-format \
		$(IOS_DIR)/HTS $(IOS_DIR)/HTSTests $(KIT_DIR)/Sources $(KIT_DIR)/Tests $(KIT_DIR)/Package.swift

ios-lint:
	swift format lint --strict --recursive --configuration $(IOS_DIR)/.swift-format \
		$(IOS_DIR)/HTS $(IOS_DIR)/HTSTests $(KIT_DIR)/Sources $(KIT_DIR)/Tests $(KIT_DIR)/Package.swift

# Physical iPhone (needs apps/ios/Local.xcconfig, see Local.xcconfig.example).
ios-device: ios-generate
	scripts/ios-run-device.sh

ios-team-id:
	@scripts/ios-team-id.sh

ios-mac-host:
	@echo "http:/\$$()/$$(scutil --get LocalHostName).local:8787"
