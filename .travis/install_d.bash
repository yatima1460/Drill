#!/bin/bash

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
    wget -nv http://downloads.dlang.org/releases/2.x/"$DMD_VERSION"/dmd."$DMD_VERSION".linux.tar.xz
    tar -xf dmd."$DMD_VERSION".linux.tar.xz 1>/dev/null -C dmd."$DMD_VERSION"
    export DUB_LOCATION=$PWD/dmd."$DMD_VERSION"/linux/bin64
    chmod +x "$DUB_LOCATION"/dmd
    chmod +x "$DUB_LOCATION"/dub
    export "PATH=$DUB_LOCATION:$PATH"
fi
if [ "$TRAVIS_OS_NAME" = "windows" ]; then
    wget -nv http://downloads.dlang.org/releases/2.x/"$DMD_VERSION"/dmd."$DMD_VERSION".windows.zip 
    echo "dmd downloaded"
    7z -bso0 -bsp0 x dmd."$DMD_VERSION".windows.zip dmd."$DMD_VERSION"
    echo "dmd extracted"
    export "PATH=$PWD/dmd.""$DMD_VERSION""/windows/bin:$PATH"
    echo "PATH set"
fi
if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    wget -nv http://downloads.dlang.org/releases/2.x/"$DMD_VERSION"/dmd."$DMD_VERSION".osx.tar.xz
    tar -xf dmd."$DMD_VERSION".osx.tar.xz 1>/dev/null -C dmd."$DMD_VERSION"
    export DUB_LOCATION=$PWD/dmd."$DMD_VERSION"/osx/bin
    chmod +x "$DUB_LOCATION"/dmd
    chmod +x "$DUB_LOCATION"/dub
    export "PATH=$DUB_LOCATION:$PATH"
fi
echo "D installed for ""$TRAVIS_OS_NAME"
dmd --version
dub --version