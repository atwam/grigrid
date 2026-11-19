APP_NAME   := Grigrid
BUILD_DIR  := build
APP        := $(BUILD_DIR)/$(APP_NAME).app
CONFIG     ?= release
SIGN_ID    ?= -

.PHONY: build app run test clean

build:
	swift build -c $(CONFIG)

app: build
	@BIN_DIR=$$(swift build -c $(CONFIG) --show-bin-path); \
	rm -rf "$(APP)"; \
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"; \
	cp "$$BIN_DIR/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"; \
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force -s "$(SIGN_ID)" "$(APP)"
	@echo "Built $(APP)"

run: app
	open "$(APP)"

test:
	swift test

clean:
	rm -rf .build $(BUILD_DIR)
