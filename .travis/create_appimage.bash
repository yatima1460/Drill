#!/bin/bash

sudo apt install -y appstream
mkdir -p Drill.AppDir
cp -R $PWD/Build/Drill-GTK-linux-x86_64-release-travis/* Drill.AppDir
mkdir -p Drill.AppDir/usr/share/metainfo
mkdir -p Drill.AppDir/usr/share/applications
cp Assets/GTK-Linux/drill.software.appdata.xml Drill.AppDir/usr/share/metainfo
cp Assets/GTK-Linux/software.drill.Drill.desktop Drill.AppDir/usr/share/applications
ln -s drill-gtk Drill.AppDir/AppRun
chmod +x Drill.AppDir/AppRun
chmod +x Drill.AppDir/drill-gtk
cp Assets/GTK-Linux/drill-gtk.svg Drill.AppDir
wget https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage -O appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
export ARCH=x86_64 && ./appimagetool-x86_64.AppImage Drill.AppDir Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-x86_64.AppImage
test -f Drill-$MAIN_VERSION.$TRAVIS_BUILD_NUMBER-x86_64.AppImage