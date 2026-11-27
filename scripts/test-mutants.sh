#!/usr/bin/env bash
# Run from any directory. cargo-mutants builds its own temporary source copies.
set -euo pipefail
cd "$(dirname "$0")/.."
scope=${1:?Choose core, query, desktop, guest or appimage}
campaign=${2:-smoke}
cargo_bin=${CARGO:-cargo}
args=(--cargo-arg=--locked --jobs 1 --build-timeout 900 --timeout 90 --caught)
case "$scope" in
  query) args+=(-p drill-query --all-features) ;;
  core) args+=(-p drill-core) ;;
  desktop) args+=(-p drill-desktop -p drill-icons --test-package drill-desktop --test-package drill-icons) ;;
  guest) args+=(--dir tools/exe-icon-wasm) ;;
  appimage) args+=(--dir tools/appimage-icon-wasm) ;;
  *) echo "Unknown mutation scope: $scope" >&2; exit 2 ;;
esac
case "$campaign" in
  smoke)
    case "$scope" in
      query) args+=(--file lib.rs --re 'SearchQuery::exact_stem') ;;
      core) args+=(--file file_filter.rs) ;;
      desktop) args+=(--file result_order.rs --file lib.rs --file icons.rs
                      --re 'exact_batch|EmbeddedIcon::for_(entry|path)|EmbeddedIcons::request') ;;
      guest) args+=(--file resource.rs) ;;
      appimage) args+=(--file bounds.rs) ;;
    esac ;;
  full)
    if [[ "$scope" == desktop && $(uname -s) != Linux ]]; then
      args+=(--exclude linux_apps.rs)
    fi ;;
  *) echo "Unknown mutation campaign: $campaign" >&2; exit 2 ;;
esac
if [[ -n "${MUTATION_SHARD:-}" ]]; then
  args+=(--shard "$MUTATION_SHARD")
fi
report="$PWD/target/mutations/$scope"
mkdir -p "$report"
"$cargo_bin" mutants "${args[@]}" --output "$report"
# cargo-mutants can exit successfully when a selector is stale or every mutant
# fails to compile. A smoke check needs at least one test-detected change.
if [[ "$campaign" == smoke ]]; then
  [[ -s "$report/mutants.out/caught.txt" ]] || { echo "No mutant caught in $scope" >&2; exit 1; }
fi
