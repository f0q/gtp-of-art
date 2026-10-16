# Homebrew tools by absolute path, so a broken or minimal shell PATH cannot hide them.
XCODEGEN ?= $(shell command -v xcodegen 2>/dev/null || echo /opt/homebrew/bin/xcodegen)
XCBEAUTIFY ?= $(shell command -v xcbeautify 2>/dev/null || echo /opt/homebrew/bin/xcbeautify)

SIM ?= ArtCI-26
SCHEME ?= ArtPrice
PROJECT ?= ArtPrice.xcodeproj
DD ?= .build/dd
PY ?= tools/.venv/bin/python

# Toolchain: prefer /Applications/Xcode.app without requiring `sudo xcode-select`.
# Override with `make DEVELOPER_DIR=/path/to/Xcode.app ...` or by exporting DEVELOPER_DIR.
ifeq ($(origin DEVELOPER_DIR), undefined)
ifneq ($(wildcard /Applications/Xcode.app),)
export DEVELOPER_DIR := /Applications/Xcode.app
endif
endif

# Swift Testing under Command Line Tools (no Xcode) needs the Testing framework path.
# When Xcode is in use these flags are unnecessary and are skipped.
CLT_FW := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_LIB := /Library/Developer/CommandLineTools/Library/Developer/usr/lib
ifeq ($(DEVELOPER_DIR),)
ifeq ($(shell xcode-select -p),/Library/Developer/CommandLineTools)
SWIFT_TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT_FW) -Xlinker -rpath -Xlinker $(CLT_FW) -Xlinker -rpath -Xlinker $(CLT_LIB)
endif
endif
SWIFT_TEST_FLAGS ?=

.PHONY: setup project build test test-core test-data test-design test-packages dataset assets fixtures clean

setup:
	/opt/homebrew/bin/brew list xcodegen >/dev/null 2>&1 || /opt/homebrew/bin/brew install xcodegen
	/opt/homebrew/bin/brew list xcbeautify >/dev/null 2>&1 || /opt/homebrew/bin/brew install xcbeautify
	test -d tools/.venv || /opt/homebrew/bin/python3.13 -m venv tools/.venv
	$(PY) -m pip install -q -r tools/requirements.txt
	@test -f .claude/skills/ui-ux-pro-max/scripts/search.py && echo "ui-ux-pro-max skill: ok" || echo "ui-ux-pro-max skill: missing (npx ui-ux-pro-max-cli init --ai claude)"

project:
	$(XCODEGEN) generate

build: project
	set -o pipefail && xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
	  -destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DD) | $(XCBEAUTIFY)

test: project
	set -o pipefail && xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -testPlan Unit \
	  -destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DD) \
	  -resultBundlePath .build/results/unit-$$(date +%s).xcresult | $(XCBEAUTIFY)

test-core:
	swift test --package-path Packages/ArtCore $(SWIFT_TEST_FLAGS)

test-data:
	swift test --package-path Packages/ArtData $(SWIFT_TEST_FLAGS)

test-design:
	swift test --package-path Packages/ArtDesign $(SWIFT_TEST_FLAGS)

test-packages: test-core test-data test-design

dataset:
	$(PY) tools/build_dataset.py --csv tools/curation/works.csv --out Resources

review:                    ## click-to-approve contact sheet at http://localhost:8765 (writes tools/curation/reviews.json)
	python3 tools/review_server.py --open

review-export:             ## portable contact sheet: tools/out/review/ (+ zip) to open from any disk or computer
	python3 tools/export_review.py

signoff:                   ## turn reviews.json approvals into tools/curation/signoff.json
	python3 tools/signoff.py --from-reviews

assets:
	$(PY) tools/make_assets.py --src tools/out/images --dst Resources/Artworks

fixtures:
	swift run --package-path Packages/ArtCore FixtureGen spec/fixtures
	git --no-pager diff --stat spec/fixtures

clean:
	rm -rf .build $(PROJECT)

# --- App targets (appended by the app engineer) -------------------------------------------------
# DerivedData must live outside ~/Documents: Xcode's debug builds add an rpath to
# <DerivedData>/Build/Products/.../PackageFrameworks, and a simulator process that opens a path
# under a TCC-protected folder (~/Documents) blocks at launch ("test runner hung before
# establishing connection"). Override on the command line with `make DD=...` if needed.
DD := $(HOME)/Library/Developer/ArtPrice/DerivedData
# ArtCI-18 needs its OS pinned: a name-only destination resolves to OS:latest (26.x) and fails.
DEST_26 ?= platform=iOS Simulator,name=ArtCI-26
DEST_18 ?= platform=iOS Simulator,name=ArtCI-18,OS=18.6
SHOTS ?= .build/shots

.PHONY: build-18 ui-test run shots

build-18: project
	set -o pipefail && xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
	  -destination '$(DEST_18)' -derivedDataPath $(DD) | $(XCBEAUTIFY)

ui-test: project
	set -o pipefail && xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -testPlan UI \
	  -destination '$(DEST_26)' -destination '$(DEST_18)' \
	  -derivedDataPath $(DD) -resultBundlePath .build/results/ui-$$(date +%s).xcresult | $(XCBEAUTIFY)

run: build
	xcrun simctl boot $(SIM) 2>/dev/null || true
	xcrun simctl bootstatus $(SIM) -b
	xcrun simctl install $(SIM) $(DD)/Build/Products/Debug-iphonesimulator/ArtPrice.app
	xcrun simctl launch $(SIM) pro.aijam.gtp-art $(ARGS)

# Screenshots of Home, Pick the price (question + reveal), Bid and Pricier via DEBUG launch args.
shots: build
	Tests/Scripts/shots.sh $(SIM) $(DD)/Build/Products/Debug-iphonesimulator/ArtPrice.app $(SHOTS)

# Screenshots in an explicit appearance (the script restores light afterwards).
.PHONY: shots-light shots-dark
shots-light: build
	Tests/Scripts/shots.sh $(SIM) $(DD)/Build/Products/Debug-iphonesimulator/ArtPrice.app $(SHOTS) light

shots-dark: build
	Tests/Scripts/shots.sh $(SIM) $(DD)/Build/Products/Debug-iphonesimulator/ArtPrice.app $(SHOTS)-dark dark

# --- Swipe / taste screenshots (appended by feature engineer B) ---------------------------------
# swipe.png, taste-reveal.png, taste-profile.png, collection.png via DEBUG launch args.
.PHONY: shots-swipe
shots-swipe: build
	xcrun simctl boot $(SIM) 2>/dev/null || true
	xcrun simctl bootstatus $(SIM) -b >/dev/null
	xcrun simctl install $(SIM) $(DD)/Build/Products/Debug-iphonesimulator/ArtPrice.app
	mkdir -p $(SHOTS)
	@for spec in "swipe:8:-startMode swipe" "taste-reveal:9:-startMode swipe -autoAnswer" \
	  "taste-profile:5:-debugSwipes -openRoute taste" "collection:9:-debugSwipes -openRoute collection"; do \
	  name=$${spec%%:*}; rest=$${spec#*:}; wait=$${rest%%:*}; args=$${rest#*:}; \
	  xcrun simctl terminate $(SIM) pro.aijam.gtp-art 2>/dev/null || true; \
	  xcrun simctl launch $(SIM) pro.aijam.gtp-art -uiTesting -onboarded -fixedDay 2026-10-12 $$args >/dev/null; \
	  sleep $$wait; xcrun simctl io $(SIM) screenshot $(SHOTS)/$$name.png >/dev/null 2>&1; echo $(SHOTS)/$$name.png; \
	done
	xcrun simctl terminate $(SIM) pro.aijam.gtp-art 2>/dev/null || true
