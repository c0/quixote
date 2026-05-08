.PHONY: setup generate build test open dev site-dev site-build release

setup:
	brew install xcodegen

generate:
	xcodegen generate

build:
	xcodebuild -project Quixote.xcodeproj \
	           -scheme Quixote \
	           -configuration Release \
	           -derivedDataPath .build

test:
	xcodebuild test -project Quixote.xcodeproj \
	           -scheme Quixote \
	           -destination 'platform=macOS' \
	           -derivedDataPath .build

open:
	open Quixote.xcodeproj

dev:
	xcodebuild -project Quixote.xcodeproj -scheme Quixote \
	           -configuration Debug -derivedDataPath .build build \
	  && open .build/Build/Products/Debug/Quixote.app

site-dev:
	cd site && npm ci && npm run dev

site-build:
	cd site && npm ci && npm run build

release:
	@[ -f .env ] || (echo "ERROR: .env not found. Copy .env.example."; exit 1)
	@bash scripts/release.sh $(VERSION)
