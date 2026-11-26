#!/usr/bin/env bash
set -euo pipefail

cache_dir=$1
cache_hit=$2
upstream=$3
cd -- "$cache_dir"
if [[ $cache_hit != true ]]; then
    curl --fail --location --retry 3 --output jscpd.tar.gz "$upstream"
fi
printf '%s  jscpd.tar.gz\n' "$JSCPD_SHA256" | sha256sum -c -
tar -xzf jscpd.tar.gz jscpd
