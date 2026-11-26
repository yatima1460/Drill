# Common development commands. Run `make help` to list them.
CARGO ?= $(if $(wildcard $(HOME)/.cargo/bin/cargo),$(HOME)/.cargo/bin/cargo,cargo)
WINE ?= wine
WINDOWS_LINKER ?= $(if $(CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER),$(CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER),x86_64-w64-mingw32-gcc)

.PHONY: help start start_wine build check fmt fmt-check lint shellcheck test test-core test-doc test-ui test-ui-headless test-ui-native package-linux package-macos offline-source clean
.DEFAULT_GOAL := help

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Build and start Drill in release mode
	$(CARGO) run --release --locked

start_wine: ## Build the Windows version and run it with Wine
	@command -v "$$WINE" >/dev/null 2>&1 || { echo 'Wine not found. Install Wine or set WINE to its executable.' >&2; exit 1; }
	@command -v "$$WINDOWS_LINKER" >/dev/null 2>&1 || { echo 'Windows cross-linker not found. Install MinGW-w64 or set WINDOWS_LINKER.' >&2; exit 1; }
	@if [ "$${CARGO_ENCODED_RUSTFLAGS+x}" = x ]; then \
		sep=$$(printf '\037'); \
		if [ -n "$$CARGO_ENCODED_RUSTFLAGS" ]; then CARGO_ENCODED_RUSTFLAGS="$$CARGO_ENCODED_RUSTFLAGS$$sep"; fi; \
		export CARGO_ENCODED_RUSTFLAGS="$${CARGO_ENCODED_RUSTFLAGS}-C$${sep}target-feature=+crt-static"; \
	fi; \
	CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$$WINDOWS_LINKER" CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUNNER=./scripts/wine-runner.sh RUSTFLAGS="$${RUSTFLAGS-} -C target-feature=+crt-static" "$$CARGO" run --locked --release -p drill --bin drill --target x86_64-pc-windows-gnu
start_wine: export CARGO := $(CARGO)
start_wine: export WINE := $(WINE)
start_wine: export WINDOWS_LINKER := $(WINDOWS_LINKER)
start_wine: export RUSTFLAGS := $(RUSTFLAGS)

build: ## Build the release application
	$(CARGO) build --release --locked

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
test-mutants: ## Run the focused mutation tests for all first-party Rust packages
	scripts/test-mutants.sh query
	scripts/test-mutants.sh core
	scripts/test-mutants.sh desktop
	scripts/test-mutants.sh guest
	scripts/test-mutants.sh appimage

test-core: ## Run search core tests without the UI
	$(CARGO) test --locked -p drill-query -p drill-core

test-doc: ## Run Rust documentation tests
	$(CARGO) test --locked --workspace --doc

test-ui-headless: ## Run fast egui interface tests
	$(CARGO) test --locked -p drill --bin drill

test-ui-native: ## Open a real window and drive OS input
	@echo 'The native UI test moves the mouse and types. Do not use them until it finishes.'
	@if [ "$$(uname -s)" = Linux ]; then \
		CARGO="$(CARGO)" xvfb-run -a scripts/test-native-ui-linux.sh; \
	else \
		$(CARGO) test --locked -p drill --features ui-test-driver --test native_ui -- --ignored --nocapture --test-threads=1; \
	fi

test-ui: test-ui-headless test-ui-native ## Run both UI test suites

package-linux: build ## Build Linux packages (requires packaging tools)
	scripts/package-linux.sh

package-macos: build ## Build and verify a macOS DMG
	scripts/package-macos.sh

offline-source: ## Package source and locked dependencies for an offline build
	scripts/package-offline-source.sh

clean: ## Remove Cargo build artifacts
	$(CARGO) clean
