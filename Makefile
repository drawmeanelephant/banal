SWIFT ?= swift
VERSION ?= 0.1.0
DIST ?= dist
APP = $(DIST)/BANAL.app
SIGN_IDENTITY ?= -
ENTITLEMENTS = Supporting/BANAL.entitlements

.PHONY: test build run app clean

test:
	$(SWIFT) test

build:
	$(SWIFT) build

run:
	$(SWIFT) run BANAL

# Signed .app for dragging to /Applications. Ad-hoc (`-`) unless
# SIGN_IDENTITY is a Developer ID Application identity.
app:
	$(SWIFT) build -c release --product BANAL
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp .build/release/BANAL "$(APP)/Contents/MacOS/BANAL"
	chmod +x "$(APP)/Contents/MacOS/BANAL"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp Supporting/Info.plist "$(APP)/Contents/Info.plist"
	printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	codesign --force --sign "$(SIGN_IDENTITY)" --entitlements "$(ENTITLEMENTS)" --timestamp=none "$(APP)"
	@echo "Built $(APP) (version $(VERSION))."
	@echo "Signed with identity '$(SIGN_IDENTITY)'."
	@echo "Ad-hoc unless SIGN_IDENTITY is a Developer ID. Not notarized."

clean:
	$(SWIFT) package clean
	rm -rf .build "$(DIST)"
