APP_NAME := NotchHero
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SWIFT := env DEVELOPER_DIR=$(DEVELOPER_DIR) swift

.PHONY: help run build release clean

help:
	@printf "Notch Hero commands:\n"
	@printf "  make run      Run the app\n"
	@printf "  make build    Build a debug binary\n"
	@printf "  make release  Build a release binary\n"
	@printf "  make clean    Remove build artifacts\n"

run:
	$(SWIFT) run $(APP_NAME)

build:
	$(SWIFT) build

release:
	$(SWIFT) build -c release

clean:
	$(SWIFT) package clean
