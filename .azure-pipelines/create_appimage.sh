#!/bin/bash
set -e
mkdir -p $(Pipeline.Workspace)/Drill.AppDir
cp -R $(Pipeline.Workspace)/Drill-GTK-linux-x86_64-release/* $(Pipeline.Workspace)/Drill.AppDir
mkdir -p $(Pipeline.Workspace)/Drill.AppDir/usr/share/metainfo
mkdir -p $(Pipeline.Workspace)/Drill.AppDir/usr/share/applications
cp $(Pipeline.Workspace)/Assets/GTK-Linux/drill.software.appdata.xml $(Pipeline.Workspace)/Drill.AppDir/usr/share/metainfo
cp $(Pipeline.Workspace)/Assets/GTK-Linux/drill-search-gtk.desktop $(Pipeline.Workspace)/Drill.AppDir/usr/share/applications
ln -s drill-search-gtk $(Pipeline.Workspace)/Drill.AppDir/AppRun
cp $(Pipeline.Workspace)/Assets/GTK-Linux/drill-search-gtk.svg $(Pipeline.Workspace)/Drill.AppDir
wget https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage -O $(Pipeline.Workspace)/appimagetool-x86_64.AppImage
chmod +x $(Pipeline.Workspace)/appimagetool-x86_64.AppImage
export ARCH=x86_64 && $(Pipeline.Workspace)/appimagetool-x86_64.AppImage $(Pipeline.Workspace)/Drill.AppDir
test -f $(Pipeline.Workspace)/Drill-x86_64.AppImage
