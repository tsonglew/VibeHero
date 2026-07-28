APP_NAME := VibeHero
PRODUCT_NAME := Vibe Hero
BUNDLE_ID := com.local.vibe-hero
APP_BUNDLE := .build/app/$(PRODUCT_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
INSTALL_DIR ?= /Applications
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SWIFT := env DEVELOPER_DIR=$(DEVELOPER_DIR) swift

.PHONY: help run dev build release app install clean

help:
	@printf "Vibe Hero commands:\n"
	@printf "  make run      Run the app\n"
	@printf "  make dev      Run and auto-restart on source changes\n"
	@printf "  make build    Build a debug binary\n"
	@printf "  make release  Build a release binary\n"
	@printf "  make app      Build Vibe Hero.app\n"
	@printf "  make install  Install Vibe Hero.app to /Applications\n"
	@printf "  make clean    Remove build artifacts\n"

run:
	$(SWIFT) run $(APP_NAME)

dev:
	APP_NAME=$(APP_NAME) DEVELOPER_DIR=$(DEVELOPER_DIR) scripts/dev-run.sh

build:
	$(SWIFT) build

release:
	$(SWIFT) build -c release

app: release
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_CONTENTS)/MacOS" "$(APP_CONTENTS)/Resources"
	@cp ".build/release/$(APP_NAME)" "$(APP_CONTENTS)/MacOS/$(PRODUCT_NAME)"
	@chmod +x "$(APP_CONTENTS)/MacOS/$(PRODUCT_NAME)"
	@printf "%s\n" \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleExecutable</key>' \
		'  <string>$(PRODUCT_NAME)</string>' \
		'  <key>CFBundleIdentifier</key>' \
		'  <string>$(BUNDLE_ID)</string>' \
		'  <key>CFBundleName</key>' \
		'  <string>$(PRODUCT_NAME)</string>' \
		'  <key>CFBundleDisplayName</key>' \
		'  <string>$(PRODUCT_NAME)</string>' \
		'  <key>CFBundlePackageType</key>' \
		'  <string>APPL</string>' \
		'  <key>CFBundleShortVersionString</key>' \
		'  <string>0.1.0</string>' \
		'  <key>CFBundleVersion</key>' \
		'  <string>1</string>' \
		'  <key>LSMinimumSystemVersion</key>' \
		'  <string>14.0</string>' \
		'  <key>LSUIElement</key>' \
		'  <true/>' \
		'  <key>NSHighResolutionCapable</key>' \
		'  <true/>' \
		'</dict>' \
		'</plist>' \
		> "$(APP_CONTENTS)/Info.plist"
	@printf "Built %s\n" "$(APP_BUNDLE)"

install: app
	@rm -rf "$(INSTALL_DIR)/$(PRODUCT_NAME).app"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(PRODUCT_NAME).app"
	@printf "Installed %s\n" "$(INSTALL_DIR)/$(PRODUCT_NAME).app"

clean:
	$(SWIFT) package clean
