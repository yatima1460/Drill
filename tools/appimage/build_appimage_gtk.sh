#! /bin/bash

echo Removed old AppImage files
wget -c https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage
echo Downloaded pkg2appimage script
echo Building AppImage...
bash pkg2appimage drill_gtk.yml
rm pkg2appimage
mv out/*.AppImage ./Drill-x64.AppImage
rmdir out
chmod +x Drill-x64.AppImage