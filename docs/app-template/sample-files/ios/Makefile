.PHONY: setup generate build open dev release

setup:
	brew install xcodegen
	brew install xcpretty

generate:
	xcodegen generate

build:
	xcodebuild -project APP_NAME.xcodeproj \
	           -scheme APP_NAME \
	           -configuration Release \
	           -sdk iphonesimulator \
	           -derivedDataPath .build

open:
	open APP_NAME.xcodeproj

dev:
	xcodebuild -project APP_NAME.xcodeproj \
	           -scheme APP_NAME \
	           -configuration Debug \
	           -sdk iphonesimulator \
	           -destination 'platform=iOS Simulator,name=iPhone 16' \
	           -derivedDataPath .build build

release:
	@[ -f .env ] || (echo "ERROR: .env not found. Copy .env.example."; exit 1)
	@bash scripts/release.sh $(VERSION)
