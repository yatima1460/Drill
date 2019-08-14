#!/bin/bash

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
    sudo apt update 1>/dev/null
    sudo apt install -y libgtk-3-dev 1>/dev/null
fi
if [ "$TRAVIS_OS_NAME" = "windows" ]; then
    wget -nv https://github.com/yatima1460/GTK3-Windows/releases/download/20190809.4/GTK_x86_64_VS2019.zip
    7z -bso0 -bsp0 x GTK_x86_64_VS2019.zip
fi
if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    wget http://www.tarnyko.net/repo/gtk3_build_system/gtk+-bundle_3.6.4_20130630_macosx.tar.bz2
    tar -xf gtk+-bundle_3.6.4_20130630_macosx.tar.bz2
    sudo mv Gtk3.framework /Library/Frameworks
    # brew install gtk+3 1>/dev/null
    # brew install glib 1>/dev/null
    # brew install gobject-introspection 1>/dev/null
fi
echo "GTK installed for "$TRAVIS_OS_NAME""