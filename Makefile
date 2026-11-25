# Common development commands. Run `make help` to list them.
CARGO ?= $(if $(wildcard $(HOME)/.cargo/bin/cargo),$(HOME)/.cargo/bin/cargo,cargo)

.PHONY: help start build check fmt fmt-check lint shellcheck test test-core test-doc test-ui test-ui-headless test-ui-native package-linux package-macos clean
.DEFAULT_GOAL := help

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Build and start Drill in release mode
	$(CARGO) run --release --locked

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

test-core: ## Run search core tests without the UI
	$(CARGO) test --locked -p drill-core

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

clean: ## Remove Cargo build artifacts
	$(CARGO) clean
