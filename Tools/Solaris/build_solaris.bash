#!/bin/bash



sudo rm -rf Build
sudo rm *.pkg
mkdir Build

FILES="../../Tools/deb/Build/*"
for f in $FILES
do
    if [[ $f == *"CLI"* ]]; then
        file_without_ext=$(basename "$f" .deb)
        sudo alien --to-pkg "$f" --target=amd64 --keep-version
        mv *.pkg "$file_without_ext".pkg
        mv "$file_without_ext".pkg Build
    fi
done

sudo chown -R "$(whoami)" Build



