#!/bin/bash

if [ "$TRAVIS_OS" = "linux" ]; then
    wget http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.linux.tar.xz
    7z x -aos dmd.$DMD_VERSION.linux.tar.xz
    7z x -aos dmd.$DMD_VERSION.linux.tar
    export DUB_LOCATION=$PWD/dmd2/linux/bin64
    chmod +x $DUB_LOCATION/dmd
    chmod +x $DUB_LOCATION/dub
    export PATH=$DUB_LOCATION:$PATH
fi
if [ "$TRAVIS_OS" = "windows" ]; then
    wget http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.windows.zip 
    7z x dmd.$DMD_VERSION.windows.zip
    export PATH=/dmd2/windows/bin:$PATH
fi
if [ "$TRAVIS_OS" = "osx" ]; then
    brew install p7zip
    wget http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.osx.tar.xz
    7z -aoa x dmd.$DMD_VERSION.osx.tar.xz
    7z -aoa x dmd.$DMD_VERSION.osx.tar
    export DUB_LOCATION=$PWD/dmd2/osx/bin
    chmod +x $DUB_LOCATION/dmd
    chmod +x $DUB_LOCATION/dub
    export PATH=$DUB_LOCATION:$PATH
fi
echo "D installed for "$TRAVIS_OS""