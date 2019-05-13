#! /bin/bash

echo Removed old AppImage files
wget -c https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage
echo Downloaded pkg2appimage script
echo Building AppImage...
bash pkg2appimage drill_gtk.yml
rm pkg2appimage
cd out
chmod +x *.AppImage
mv *.AppImage ../Drill-$(head -n 1 ../../../DRILL_VERSION)-GTK.AppImage
cd ..
rmdir out