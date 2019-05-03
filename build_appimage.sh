#! /bin/bash

rm *.AppImage
rm -rf me.santamorena.drill
echo Removed old AppImage files
wget https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage
echo Downloaded pkg2appimage script
echo Building AppImage...
bash pkg2appimage drill.yml
cd out
mv *.AppImage ..
cd ..
rmdir out
rm pkg2appimage
echo AppImage built