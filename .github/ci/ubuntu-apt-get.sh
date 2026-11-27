#!/usr/bin/env bash
set -euo pipefail

# The hosted runner also configures vendor feeds. Drill's packages all come
# from the Ubuntu archive, including its updates and security repositories.
sources=/etc/apt/sources.list.d/ubuntu.sources
if [[ ! -s "$sources" ]]; then
    echo "Missing Ubuntu package sources: $sources" >&2
    exit 1
fi
exec sudo apt-get -o "Dir::Etc::sourcelist=$sources" -o Dir::Etc::sourceparts=/dev/null "$@"
