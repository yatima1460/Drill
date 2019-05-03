#! /bin/bash

rm *.AppImage
echo Removed old AppImage files
wget https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage &> /dev/null
echo Downloaded pkg2appimage script
echo Building AppImage...
bash pkg2appimage drill.yml &> /dev/null
cd out
mv *.AppImage ..
cd ..
rmdir out
rm -rf me.santamorena.drill &> /dev/null
rm pkg2appimage
echo AppImage built