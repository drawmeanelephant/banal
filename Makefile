SWIFT ?= swift

.PHONY: test build run clean

test:
	$(SWIFT) test

build:
	$(SWIFT) build

run:
	$(SWIFT) run BANAL

clean:
	$(SWIFT) package clean
	rm -rf .build
