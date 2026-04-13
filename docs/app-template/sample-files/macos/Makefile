.PHONY: setup generate build open dev release

setup:
	brew install xcodegen
	brew install gh
	brew install xcpretty

generate:
	xcodegen generate

build:
	xcodebuild -project APP_NAME.xcodeproj \
	           -scheme APP_NAME \
	           -configuration Release \
	           -derivedDataPath .build

open:
	open APP_NAME.xcodeproj

dev:
	xcodebuild -project APP_NAME.xcodeproj -scheme APP_NAME \
	           -configuration Debug -derivedDataPath .build build \
	  && open .build/Build/Products/Debug/APP_NAME.app

release:
	@[ -f .env ] || (echo "ERROR: .env not found. Copy .env.example."; exit 1)
	@bash scripts/release.sh $(VERSION)
