#!/bin/bash

# Dependencies
source .travis/install_d.bash
source .travis/install_gtk.bash

# Unittests
dub test -c CLI || travis_terminate 1  &
dub test -c GTK || travis_terminate 1  &
wait

# Builds
echo $MAIN_VERSION.$TRAVIS_BUILD_NUMBER > TRAVIS_VERSION
dub build -c CLI -b release-travis || travis_terminate 1 &
dub build -c GTK -b release-travis || travis_terminate 1 &
wait

# Packages
7z a -tzip Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-CLI-$TRAVIS_OS_NAME-x86_64.zip $PWD/Build/Drill-GTK-$TRAVIS_OS_NAME-x86_64-release-travis/* || travis_terminate 1 &
7z a -tzip Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-GTK-$TRAVIS_OS_NAME-x86_64.zip $PWD/Build/Drill-CLI-$TRAVIS_OS_NAME-x86_64-release-travis/* || travis_terminate 1 &
wait

# if this is a pull request we stop here
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then travis_terminate 1; fi

# Upload fresh beta packages
curl -T Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-CLI-$TRAVIS_OS_NAME-x86_64.zip -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/Portable-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-CLI-$TRAVIS_OS_NAME-x86_64.zip
curl -X POST -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/Portable-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/publish