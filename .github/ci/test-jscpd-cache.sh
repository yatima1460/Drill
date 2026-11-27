#!/usr/bin/env bash
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
prepare=.github/ci/prepare-jscpd.sh
cp -R -- "$RUNNER_TEMP/jscpd-cache" "$work/cache"
mkdir "$work/bin" "$work/duplicates"
printf '#!/bin/sh\nexit 42\n' > "$work/bin/cargo"
chmod +x "$work/bin/cargo"
export PATH="$work/bin:$PATH"
bash "$prepare" "$work/cache" true

cp .jscpd.json "$work/duplicates/"
# Keep the detection fixture independent of the desktop UI's source layout.
cat > "$work/duplicates/one.rs" <<'RUST'
fn total_within_bounds(values: &[u64], minimum: u64, maximum: u64) -> u64 {
    let mut total = 0_u64;
    for &value in values {
        if value >= minimum && value <= maximum {
            total = total.saturating_add(value);
        }
    }
    total
}
RUST
cp "$work/duplicates/one.rs" "$work/duplicates/two.rs"
if (cd "$work/duplicates" && "$work/cache/jscpd" .) > "$work/scan.log" 2>&1; then
    echo 'jscpd accepted duplicate source' >&2
    exit 1
fi
grep -Fq 'Clone found' "$work/scan.log"

printf '#!/bin/sh\ntouch invoked\necho "jscpd 5.4.3"\n' > "$work/cache/jscpd"
if bash "$prepare" "$work/cache" true > "$work/verify.log" 2>&1; then
    echo 'jscpd accepted a corrupt executable' >&2
    exit 1
fi
grep -Fq 'checksum mismatch' "$work/verify.log"
test ! -e "$work/cache/invoked"
