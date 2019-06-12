#!/bin/bash


if [ -z "$TRAVIS_TAG" ]; then
  echo No Drill version found! Using LOCAL_BUILD
  export TRAVIS_TAG="LOCAL_BUILD"
fi

#cp ../deb/Build/Drill-GTK-linux-x86_64-release-$TRAVIS_TAG.deb .

wget -c https://raw.githubusercontent.com/probonopd/AppImages/master/pkg2appimage

bash -ex ./pkg2appimage Drill_GTK.yml

#rm Drill-GTK-linux-x86_64-release-$TRAVIS_TAG.deb

mkdir -p Build
mv out/*.AppImage Build/Drill-GTK-linux-x86_64-release-$TRAVIS_TAG.AppImage
rmdir out