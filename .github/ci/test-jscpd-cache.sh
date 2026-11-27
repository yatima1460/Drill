#!/usr/bin/env bash
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
prepare=.github/ci/prepare-jscpd.sh
upstream=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).as_uri())' "$RUNNER_TEMP/jscpd.tar.gz")
offline="file://$work/unavailable"

# Each case starts with no extracted executable. Only the archive survives.
bash "$prepare" "$work" '' "$upstream"
rm -- "$work/jscpd"
bash "$prepare" "$work" true "$offline"
test "$("$work/jscpd" --version)" = "jscpd $JSCPD_VERSION"

mkdir "$work/duplicates"
cp .jscpd.json "$work/duplicates/"
cp src/search_mode.rs "$work/duplicates/one.rs"
cp src/search_mode.rs "$work/duplicates/two.rs"
if (cd "$work/duplicates" && "$work/jscpd" .) > "$work/scan.log" 2>&1; then
    echo 'jscpd accepted duplicate source' >&2
    exit 1
fi
grep -Fq 'Clone found' "$work/scan.log"

rm -- "$work/jscpd"
printf 'damaged' >> "$work/jscpd.tar.gz"
if bash "$prepare" "$work" true "$offline" > "$work/verify.log" 2>&1; then
    echo 'jscpd accepted a corrupt archive' >&2
    exit 1
fi
grep -Fq 'FAILED' "$work/verify.log"
test ! -e "$work/jscpd"
