# Common development commands. Run `make help` to list them.
CARGO ?= $(if $(wildcard $(HOME)/.cargo/bin/cargo),$(HOME)/.cargo/bin/cargo,cargo)
WINE ?= wine
WINDOWS_LINKER ?= $(if $(CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER),$(CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER),x86_64-w64-mingw32-gcc)
HOST_SYSTEM := $(if $(filter Windows_NT,$(OS)),Windows_NT,$(shell uname -s))

.PHONY: help start start_wine build check fmt fmt-check lint shellcheck test test-core test-doc test-ui test-ui-headless test-ui-native package-linux package-macos offline-source clean
.DEFAULT_GOAL := help

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Build and start the platform's Drill app
build: ## Build the platform's release application
test-ui-headless: ## Test the native UI model or private AppKit windows
test-ui-native: ## Test the interface in a native window

ifeq ($(HOST_SYSTEM),Darwin)
start: start-swift
build: build-swift-ui
# The Mac suite drives native AppKit windows with private input events.
test-ui-headless test-ui-native: test-swift-ui
else
start:
	$(CARGO) run --release --locked

build:
	$(CARGO) build --release --locked

test-ui-headless:
	$(CARGO) test --locked -p drill-desktop

test-ui-native:
ifeq ($(HOST_SYSTEM),Linux)
	CARGO="$(CARGO)" xvfb-run -a scripts/test-native-ui-linux.sh
else
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-native-ui-windows.ps1
endif
endif

.PHONY: build-swift-ui start-swift test-swift-ui
build-swift-ui test-swift-ui: export CARGO := $(CARGO)
build-swift-ui: ## Build the native macOS app
	python3 scripts/build-swift-ui.py

start-swift: build-swift-ui ## Open the native macOS app
	open "target/swift-ui/Drill.app"

test-swift-ui: ## Exercise SwiftUI in private native macOS windows
	python3 scripts/build-swift-ui.py --test

start_wine: ## Build the Windows version and run it with Wine
	@command -v "$$WINE" >/dev/null 2>&1 || { echo 'Wine not found. Install Wine or set WINE to its executable.' >&2; exit 1; }
	@command -v "$$WINDOWS_LINKER" >/dev/null 2>&1 || { echo 'Windows cross-linker not found. Install MinGW-w64 or set WINDOWS_LINKER.' >&2; exit 1; }
	@if [ -z "$${RC+x}$${RC_x86_64_pc_windows_gnu+x}" ] && \
	    ! printenv RC_x86_64-pc-windows-gnu >/dev/null 2>&1; then \
		linker=$$(command -v "$$WINDOWS_LINKER"); \
		tools=$$(dirname "$$linker"); \
		windres=$$("$$linker" -print-prog-name=windres 2>/dev/null) || windres=; \
		if [ -x "$$windres" ]; then export RC="$$windres"; \
		elif [ -n "$$windres" ] && [ -x "$$tools/$$windres" ]; then export RC="$$tools/$$windres"; \
		elif [ -x "$$tools/x86_64-w64-mingw32-windres" ]; then export RC="$$tools/x86_64-w64-mingw32-windres"; \
		fi; \
	fi; \
	if [ "$${CARGO_ENCODED_RUSTFLAGS+x}" = x ]; then \
		sep=$$(printf '\037'); \
		if [ -n "$$CARGO_ENCODED_RUSTFLAGS" ]; then CARGO_ENCODED_RUSTFLAGS="$$CARGO_ENCODED_RUSTFLAGS$$sep"; fi; \
		export CARGO_ENCODED_RUSTFLAGS="$${CARGO_ENCODED_RUSTFLAGS}-C$${sep}target-feature=+crt-static"; \
	fi; \
	CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$$WINDOWS_LINKER" CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUNNER=./scripts/wine-runner.sh RUSTFLAGS="$${RUSTFLAGS-} -C target-feature=+crt-static" "$$CARGO" run --locked --release -p drill --bin drill --target x86_64-pc-windows-gnu
start_wine: export CARGO := $(CARGO)
start_wine: export WINE := $(WINE)
start_wine: export WINDOWS_LINKER := $(WINDOWS_LINKER)
start_wine: export RUSTFLAGS := $(RUSTFLAGS)

check: ## Check all workspace targets
	$(CARGO) check --locked --workspace --all-targets

fmt: ## Format Rust code
	$(CARGO) fmt --all

fmt-check: ## Check Rust formatting
	$(CARGO) fmt --all -- --check

lint: ## Run Clippy on all workspace targets and features
	$(CARGO) clippy --locked --workspace --all-targets --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks

shellcheck: ## Lint shell scripts and launchers
	shellcheck scripts/*.sh 'Start Drill.command' 'Run UI Tests.command' 'Run Core Tests.command'

test: ## Run all non-interactive workspace tests
	$(CARGO) test --locked --workspace

.PHONY: prove test-mutants
prove: ## Model-check the search filter, row insertion and Wasm read bounds
	$(CARGO) kani --manifest-path verification/Cargo.toml --lib --output-format terse

test-mutants: export CARGO := $(CARGO)
test-mutants: ## Run focused mutation tests for search, desktop and decoder code
	scripts/test-mutants.sh query
	scripts/test-mutants.sh core
	scripts/test-mutants.sh desktop
	scripts/test-mutants.sh guest
	scripts/test-mutants.sh appimage

test-core: ## Run search core tests without the UI
	$(CARGO) test --locked -p drill-query -p drill-core

test-doc: ## Run Rust documentation tests
	$(CARGO) test --locked --workspace --doc

test-ui: test-ui-headless test-ui-native ## Run the platform's UI suite

package-linux: build ## Build Linux packages (requires packaging tools)
	scripts/package-linux.sh

package-macos: build-swift-ui ## Build and verify a macOS DMG
	scripts/package-macos.sh

offline-source: ## Package source and locked dependencies for an offline build
	scripts/package-offline-source.sh

clean: ## Remove Cargo build artifacts
	$(CARGO) clean
