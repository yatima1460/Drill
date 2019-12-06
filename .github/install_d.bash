#!/bin/bash

DMD_VERSION="2.087.1"


if [[ $GITHUB_WORKFLOW == *"Linux"* ]]; then
    wget http://downloads.dlang.org/releases/2.x/2.089.0/dmd_2.089.0-0_amd64.deb
    sudo dpkg -i dmd_2.089.0-0_amd64.deb

    # wget -nv http://downloads.dlang.org/releases/2.x/"$DMD_VERSION"/dmd."$DMD_VERSION".linux.tar.xz
    # tar -xf dmd."$DMD_VERSION".linux.tar.xz 1>/dev/null -C dmd."$DMD_VERSION"
    # export DUB_LOCATION=$PWD/dmd."$DMD_VERSION"/linux/bin64
    # chmod +x "$DUB_LOCATION"/dmd
    # chmod +x "$DUB_LOCATION"/dub
    # export "PATH=$DUB_LOCATION:$PATH"
fi
if [[ $GITHUB_WORKFLOW == *"Windows"* ]]; then
    wget -c -nv http://downloads.dlang.org/releases/2.x/"$DMD_VERSION"/dmd."$DMD_VERSION".windows.zip 
    echo "dmd downloaded"
    7z -bso0 -bsp0 x dmd."$DMD_VERSION".windows.zip dmd."$DMD_VERSION"
    echo "dmd extracted"
    export "PATH=$PWD/dmd.""$DMD_VERSION""/windows/bin:$PATH"
    echo "PATH set"
fi
if [[ $GITHUB_WORKFLOW == *"MacOS"* ]]; then
    wget -nv http://downloads.dlang.org/releases/2.x/"$DMD_VERSION"/dmd."$DMD_VERSION".osx.tar.xz
    tar -xf dmd."$DMD_VERSION".osx.tar.xz 1>/dev/null -C dmd."$DMD_VERSION"
    export DUB_LOCATION=$PWD/dmd."$DMD_VERSION"/osx/bin
    chmod +x "$DUB_LOCATION"/dmd
    chmod +x "$DUB_LOCATION"/dub
    export "PATH=$DUB_LOCATION:$PATH"
fi
echo "D installed for ""$GITHUB_WORKFLOW"
dmd --version
dub --version