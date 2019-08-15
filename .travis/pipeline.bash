#!/bin/bash



# Unittests
dub test -c CLI &
dub test -c GTK &
if [ "$TRAVIS_OS_NAME" = "windows" ]; then
    dub test -c WinAPI &
fi
wait

# Builds
echo "$MAIN_VERSION"."$TRAVIS_BUILD_NUMBER" > TRAVIS_VERSION
dub build -c CLI -b release-travis &
dub build -c GTK -b release-travis &
if [ "$TRAVIS_OS_NAME" = "windows" ]; then
    dub build -c WinAPI -b release-travis
fi
wait




# if this is a pull request we stop here
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then 
    echo "Pull request detected, skipping building of packages"
    travis_terminate 0;
    exit 0;
fi



# Packages
7z a -mx0 -mmt2 -tzip Drill-"$MAIN_VERSION"."$TRAVIS_BUILD_NUMBER"-CLI-"$TRAVIS_OS_NAME"-x86_64.zip "$PWD"/Build/Drill-GTK-"$TRAVIS_OS_NAME"-x86_64-release-travis/* &
7z a -mx0 -mmt2 -tzip Drill-"$MAIN_VERSION"."$TRAVIS_BUILD_NUMBER"-GTK-"$TRAVIS_OS_NAME"-x86_64.zip "$PWD"/Build/Drill-CLI-"$TRAVIS_OS_NAME"-x86_64-release-travis/* &
if [ "$TRAVIS_OS_NAME" = "linux" ]; then
    bash .travis/create_appimage.bash &
    # source .travis/create_deb_cli.bash
    # source .travis/create_deb_gtk.bash
    # source .travis/create_rpm_cli.bash
    # source .travis/create_rpm_gtk.bash
fi
wait

# TODO: installer windows


# Upload fresh beta packages

# # CLI
# curl -T Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-CLI-$TRAVIS_OS_NAME-x86_64.zip -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/Portable-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-CLI-$TRAVIS_OS_NAME-x86_64.zip
# curl -X POST -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/Portable-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/publish

# # GTK
# curl -T Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-GTK-$TRAVIS_OS_NAME-x86_64.zip -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/Portable-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-GTK-$TRAVIS_OS_NAME-x86_64.zip
# curl -X POST -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/Portable-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/publish

# # AppImage
# if [ "$TRAVIS_OS_NAME" = "linux" ]; then
#     curl -T Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-x86_64.AppImage -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/AppImage-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-x86_64.AppImage
#     curl -X POST -uyatima1460:$BINTRAY_API_KEY https://api.bintray.com/content/yatima1460/Drill/AppImage-Beta/$MAIN_VERSION.$TRAVIS_BUILD_NUMBER/publish
# fi
