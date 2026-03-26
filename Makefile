.PHONY: setup generate build open dev release

setup:
	brew install xcodegen

generate:
	xcodegen generate

build:
	xcodebuild -project QuixoteSwift.xcodeproj \
	           -scheme QuixoteSwift \
	           -configuration Release \
	           -derivedDataPath .build

open:
	open QuixoteSwift.xcodeproj

dev:
	xcodebuild -project QuixoteSwift.xcodeproj -scheme QuixoteSwift \
	           -configuration Debug -derivedDataPath .build build \
	  && open .build/Build/Products/Debug/Quixote\ Swift.app

release:
	@[ -f .env ] || (echo "ERROR: .env not found. Copy .env.example."; exit 1)
	@bash scripts/release.sh $(VERSION)
