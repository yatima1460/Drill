#!/bin/bash

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
    sudo apt install -y libgtk-3-dev
fi
if [ "$TRAVIS_OS_NAME" = "windows" ]; then
    wget https://github.com/yatima1460/GTK3-Windows/releases/download/20190809.4/GTK_x86_64_VS2019.zip
    7z x GTK_x86_64_VS2019.zip
fi
if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    brew install gtk+3
    brew install glib
    brew install gobject-introspection
fi
echo "GTK installed for "$TRAVIS_OS_NAME""