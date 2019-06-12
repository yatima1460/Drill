#!/bin/bash



sudo rm -rf Build
sudo rm *.rpm
mkdir Build

FILES="../../Tools/deb/Build/*"
for f in $FILES
do
    file_without_ext=$(basename "$f" .deb)
    sudo alien --to-tgz "$f" --target=amd64 --keep-version
    mv *.tgz "$file_without_ext".tgz
    mv "$file_without_ext".tgz Build
done

sudo chown -R "$(whoami)" Build



