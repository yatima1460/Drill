#!/bin/bash
set -e
mkdir -p $PIPELINE_WORKSPACE/Drill.AppDir
cp -R $PIPELINE_WORKSPACE/Drill-GTK-linux-x86_64-release/* $PIPELINE_WORKSPACE/Drill.AppDir
mkdir -p $PIPELINE_WORKSPACE/Drill.AppDir/usr/share/metainfo
mkdir -p $PIPELINE_WORKSPACE/Drill.AppDir/usr/share/applications
cp $PIPELINE_WORKSPACE/Assets/GTK-Linux/drill.software.appdata.xml $PIPELINE_WORKSPACE/Drill.AppDir/usr/share/metainfo
cp $PIPELINE_WORKSPACE/Assets/GTK-Linux/drill-search-gtk.desktop $PIPELINE_WORKSPACE/Drill.AppDir/usr/share/applications
ln -s drill-search-gtk $PIPELINE_WORKSPACE/Drill.AppDir/AppRun
chmod +x $PIPELINE_WORKSPACE/Drill.AppDir/AppRun
chmod +x $PIPELINE_WORKSPACE/Drill.AppDir/drill-search-gtk
cp $PIPELINE_WORKSPACE/Assets/GTK-Linux/drill-search-gtk.svg $PIPELINE_WORKSPACE/Drill.AppDir
wget https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage -O $PIPELINE_WORKSPACE/appimagetool-x86_64.AppImage
chmod +x $PIPELINE_WORKSPACE/appimagetool-x86_64.AppImage
export ARCH=x86_64 && $PIPELINE_WORKSPACE/appimagetool-x86_64.AppImage $PIPELINE_WORKSPACE/Drill.AppDir Drill-release-x86_64.AppImage
test -f $PIPELINE_WORKSPACE/Drill-release-x86_64.AppImage
