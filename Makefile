SWIFT ?= swift
BASH ?= /bin/bash
XCODEGEN ?= xcodegen
PROJECT ?= BANAL.xcodeproj
VERSION ?= $(shell grep 'MARKETING_VERSION' Project.yml | sed 's/.*"\(.*\)"/\1/')
DIST ?= dist
APP = $(DIST)/BANAL.app
DMG = $(DIST)/BANAL-$(VERSION).dmg
SIGN_IDENTITY ?= -
ENTITLEMENTS = Supporting/BANAL.entitlements
HELP_BOOK = Resources/BANAL.help
HELP_BOOK_DEST = $(APP)/Contents/Resources/BANAL.help
HELP_BOOK_LOCALE = $(HELP_BOOK_DEST)/Contents/Resources/en.lproj
HIUTIL ?= hiutil

ifeq ($(SIGN_IDENTITY),-)
CODESIGN_FLAGS = --timestamp=none
else
CODESIGN_FLAGS = --options runtime --timestamp
endif

.PHONY: test build run app sign-developer-id notarize dmg release-dmg release smoke project ui-test clean board board-check

test:
	$(SWIFT) test

build:
	$(SWIFT) build

run:
	$(SWIFT) run BANAL

# Signed .app for dragging to /Applications. Ad-hoc (`-`) unless
# SIGN_IDENTITY is a Developer ID Application identity.
# Oliver/Boris are built from their sibling Zig checkouts and bundled
# into Contents/Helpers (Scripts/helpers.sh); missing checkouts are a
# warning, not an error — the app degrades to builtin/one-sentence paths.
app:
	$(SWIFT) build -c release --product banal-cli
	rm -rf "$(APP)"
	@$(BASH) Scripts/helpers.sh "$(DIST)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp .build/release/banal-cli "$(APP)/Contents/MacOS/BANAL"
	chmod +x "$(APP)/Contents/MacOS/BANAL"
	@if compgen -G "$(DIST)/helpers/*" >/dev/null; then \
		mkdir -p "$(APP)/Contents/Helpers"; \
		for helper in "$(DIST)/helpers/"*; do \
			cp "$$helper" "$(APP)/Contents/Helpers/"; \
			codesign --force --sign "$(SIGN_IDENTITY)" $(CODESIGN_FLAGS) "$(APP)/Contents/Helpers/`basename "$$helper"`" || exit 1; \
		done; \
	fi
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp Resources/BANAL.sdef "$(APP)/Contents/Resources/BANAL.sdef"
	cp -R "$(HELP_BOOK)" "$(APP)/Contents/Resources/"
	cp Supporting/Info.plist "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" "$(APP)/Contents/Info.plist"
	printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	@if command -v "$(HIUTIL)" >/dev/null 2>&1; then \
		"$(HIUTIL)" -I corespotlight -Caf "$(HELP_BOOK_LOCALE)/BANAL.cshelpindex" -g -s en -l en_US "$(HELP_BOOK_LOCALE)"; \
	else \
		echo "warning: hiutil not found — Help Book index not built."; \
	fi
	codesign --force --sign "$(SIGN_IDENTITY)" --entitlements "$(ENTITLEMENTS)" $(CODESIGN_FLAGS) "$(APP)"
	@echo "Built $(APP) (version $(VERSION))."
	@echo "Signed with identity '$(SIGN_IDENTITY)'."
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "Ad-hoc unless SIGN_IDENTITY is a Developer ID. Not notarized."; \
	else \
		echo "Hardened runtime enabled for Developer ID."; \
	fi

# Detect Developer ID in Keychain and sign app
sign-developer-id:
	@DEV_ID=$$(security find-identity -p codesigning -v 2>/dev/null | grep 'Developer ID Application:' | head -1 | sed -E 's/.*"([^"]+)".*/\1/'); \
	if [ -n "$$DEV_ID" ]; then \
		echo "Signing with Developer ID: $$DEV_ID"; \
		$(MAKE) app SIGN_IDENTITY="$$DEV_ID"; \
	else \
		echo "No Developer ID Application identity found in Keychain."; \
		echo "Specify explicitly: make app SIGN_IDENTITY=\"Developer ID Application: Name (ID)\""; \
		exit 1; \
	fi

# Notarize and staple dist/BANAL.app
notarize:
	$(BASH) Scripts/notarize.sh "$(APP)"

# Build DMG containing BANAL.app and /Applications shortcut
dmg:
	$(BASH) Scripts/package-dmg.sh "$(APP)" "$(VERSION)" "$(DIST)"

# Build DMG and notarize it if credentials are present
release-dmg: dmg
	$(BASH) Scripts/notarize.sh "$(DMG)"

# Full release pipeline: Developer ID / signed app, notarize app, build DMG, notarize DMG
release:
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		DEV_ID=$$(security find-identity -p codesigning -v 2>/dev/null | grep 'Developer ID Application:' | head -1 | sed -E 's/.*"([^"]+)".*/\1/'); \
		if [ -n "$$DEV_ID" ]; then \
			$(MAKE) app SIGN_IDENTITY="$$DEV_ID"; \
		else \
			$(MAKE) app; \
		fi \
	else \
		$(MAKE) app SIGN_IDENTITY="$(SIGN_IDENTITY)"; \
	fi
	$(BASH) Scripts/notarize.sh "$(APP)"
	$(BASH) Scripts/package-dmg.sh "$(APP)" "$(VERSION)" "$(DIST)"
	$(BASH) Scripts/notarize.sh "$(DMG)"
	@echo "Release build completed for BANAL $(VERSION)."

# Launch smoke: the signed app boots, opens BANAL_VAULT, quits cleanly.
smoke: app
	$(BASH) Scripts/smoke.sh

# Regenerate the XcodeGen project (BANAL.xcodeproj is not checked in).
project:
	$(XCODEGEN) generate

# XCUITest accessibility audit + window-size pass against the app target.
# Requires xcodegen; runs unit-test-free via the BANAL scheme (UI tests only).
ui-test: project
	xcodebuild test -project "$(PROJECT)" -scheme BANAL -destination 'platform=macOS' \
		-only-testing:BANALUITests

board:
	$(BASH) Scripts/generate-board.sh

board-check:
	$(BASH) Scripts/generate-board.sh --check

clean:
	$(SWIFT) package clean
	rm -rf .build "$(DIST)"
