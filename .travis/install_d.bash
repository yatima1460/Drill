#!/bin/bash

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
    sudo apt-get install -y p7zip-full
    wget -nv http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.linux.tar.xz
    7z -bso0 -bsp0 x -aos dmd.$DMD_VERSION.linux.tar.xz
    7z -bso0 -bsp0 x -aos dmd.$DMD_VERSION.linux.tar
    export DUB_LOCATION=$PWD/dmd2/linux/bin64
    chmod +x $DUB_LOCATION/dmd
    chmod +x $DUB_LOCATION/dub
    export "PATH=$DUB_LOCATION:$PATH"
fi
if [ "$TRAVIS_OS_NAME" = "windows" ]; then
    wget -nv http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.windows.zip 
    echo "dmd downloaded"
    7z -bso0 -bsp0 x dmd.$DMD_VERSION.windows.zip
    echo "dmd extracted"
    export "PATH=$PWD/dmd2/windows/bin:$PATH"
    echo "PATH set"
fi
if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    brew install p7zip
    wget -nv http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.osx.tar.xz
    7z -bso0 -bsp0 -aoa x dmd.$DMD_VERSION.osx.tar.xz
    7z -bso0 -bsp0 -aoa x dmd.$DMD_VERSION.osx.tar
    export DUB_LOCATION=$PWD/dmd2/osx/bin
    chmod +x $DUB_LOCATION/dmd
    chmod +x $DUB_LOCATION/dub
    export "PATH=$DUB_LOCATION:$PATH"
fi
echo "D installed for "$TRAVIS_OS_NAME""