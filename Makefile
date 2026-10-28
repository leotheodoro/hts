IOS_DIR := apps/ios
KIT_DIR := $(IOS_DIR)/HTSKit
PROJECT := $(IOS_DIR)/HTS.xcodeproj
SIMULATOR ?= iPhone 17 Pro Max
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
XCODEBUILD_FLAGS := -project $(PROJECT) -scheme HTS -destination "$(DESTINATION)" \
	-skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO

.PHONY: ios-generate ios-test ios-kit-test ios-app-test ios-build ios-format ios-lint

ios-generate:
	cd $(IOS_DIR) && xcodegen generate

ios-kit-test:
	cd $(KIT_DIR) && swift test

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
