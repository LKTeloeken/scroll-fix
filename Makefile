VERSION ?= 0.1.0
APP_DIR ?= /Applications
APP = build/ScrollFix.app
SOURCES = $(wildcard Sources/*.swift)
SWIFTC = swiftc -O -swift-version 5

.PHONY: build install uninstall zip clean

build: $(APP)

# Universal binary, ad-hoc signed so macOS can track the Accessibility grant.
$(APP): $(SOURCES) Resources/Info.plist Makefile
	rm -rf $@
	mkdir -p $@/Contents/MacOS
	$(SWIFTC) -target arm64-apple-macos13 $(SOURCES) -o build/ScrollFix-arm64
	$(SWIFTC) -target x86_64-apple-macos13 $(SOURCES) -o build/ScrollFix-x86_64
	lipo -create build/ScrollFix-arm64 build/ScrollFix-x86_64 -output $@/Contents/MacOS/ScrollFix
	cp Resources/Info.plist $@/Contents/Info.plist
	plutil -replace CFBundleShortVersionString -string $(VERSION) $@/Contents/Info.plist
	plutil -replace CFBundleVersion -string $(VERSION) $@/Contents/Info.plist
	codesign --force --sign - $@

install: build
	pkill -x ScrollFix || true
	rm -rf "$(APP_DIR)/ScrollFix.app"
	cp -R $(APP) "$(APP_DIR)/"
	open "$(APP_DIR)/ScrollFix.app"

uninstall:
	pkill -x ScrollFix || true
	rm -rf "$(APP_DIR)/ScrollFix.app"

zip: build
	ditto -c -k --keepParent $(APP) build/ScrollFix.zip

clean:
	rm -rf build
