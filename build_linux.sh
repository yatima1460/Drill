#!/bin/bash

#==== DRILL BUILD SETTINGS ====

CREATE_ZIP=true
CREATE_GTK=true

CREATE_APPIMAGE=true
CREATE_DEB=false


#==============================



info () {
    echo "\033[34m[DRILL BUILD][INFO]: $1\033[0m"
}

warn() {
    echo "\033[93m[DRILL BUILD][WARNING]: $1\033[0m"
}

error() {
    echo "\033[31m[DRILL BUILD][ERROR]: $1\033[0m"
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
ctrl_c() {
    error "user manually stopped build with Ctrl-C"
    pkill -P $$
    exit 2
}



rm -rf build
if [ $? -eq 0 ]; then
    info "build directory cleared"
else
    error "can't clear build directory"
    exit 1
fi

mkdir -p build
if [ $? -eq 0 ]; then
    info "build directory created"
else
    error "can't create build directory"
    exit 1
fi





# if we are running in travis use travis build number
# otherwise set string version to "LOCAL_BUILD"
if [ -z "$TRAVIS_BUILD_NUMBER" ]; then
    export TRAVIS_TAG="LOCAL_BUILD"
    export DRILL_VERSION=$TRAVIS_TAG
    warn "Not a travis build, will use '$DRILL_VERSION' as version string"
else
    export TRAVIS_TAG="1.$TRAVIS_BUILD_NUMBER"
    export DRILL_VERSION=$TRAVIS_TAG
fi

# write version to file
# it will be included in all packaged versions
echo -n $DRILL_VERSION > DRILL_VERSION

if [ "dmd --version" ] && [ "dub --version" ]; then
    info "D environment found"
else
    warn "D environment missing, will try to install dlang"
    curl -fsS https://dlang.org/install.sh | bash -s dmd;
    if [ $? -eq 0 ]; then
        info "D environment installed correctly"
    else
        error "D environment installation failed"
        exit 1
    fi
    source ~/dlang/dmd-2.086.0/activate;
    if [ $? -eq 0 ]; then
        info "D environment activated correctly"
    else
        error "D environment can't be activated"
        exit 1
    fi
fi


package() {
    7z a -tzip Drill-$1-linux-$DRILL_VERSION.zip assets drill-$1.elf DRILL_VERSION
    if [ $? -eq 0 ]; then
        info "Zipping of $1 done"
        mv Drill-$1-linux-$DRILL_VERSION.zip build
        if [ $? -eq 0 ]; then
            info "Drill-$1-linux-$DRILL_VERSION.zip moved to build folder"
        else
            error "Drill-$1-linux-$DRILL_VERSION.zip could not be moved to build folder"
        fi
    else
        error "Zipping of $1 could not find some files"
        exit 1
    fi
}

appimage() {
    cd tools/appimage
    wget -c https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage
    bash pkg2appimage $1.yml
    if [ $? -eq 0 ]; then
        info "AppImage build done"
    else
        error "AppImage build failed"
    fi
    cd ../../
    mv tools/appimage/out/*.AppImage build/Drill-$1-$DRILL_VERSION.AppImage
    chmod +x build/Drill-$1-$DRILL_VERSION.AppImage
    rmdir tools/appimage/out
    rm tools/pkg2appimage
}


build() {
    info "Starting build of $1..."
    cd $1
    dub build -b release --parallel --arch=x86_64
    if [ $? -eq 0 ]; then
        info "$1 built correctly"
    else
        error "Building $1... failed"
        exit 1
    fi
    cd -
}

appdir() {
    mkdir               build/$1
    cp -r assets        build/$1
    cp drill-$1.elf     build/$1
    cp DRILL_VERSION    build/$1
}



pipeline() {
    build "source/core/datefmt" || exit 1 &
    build "source/gtkui" || exit 1 &
    wait
    build "source/core" || exit 1 &
    wait
    build "source/cli" || exit 1 &
    build "source/gtkui/GtkD" || exit 1 &
    wait
    appdir "cli" || exit 1 &
    appdir "gtk" || exit 1 &
    package "cli" || exit 1 &
    package "gtk" || exit 1 &
    if $CREATE_APPIMAGE; then
        appimage "gtk" || exit 1 &
    else
        warn ".AppImage creation manually skipped"
    fi
    if $CREATE_DEB; then
        deb "gtk" || exit 1 &
        deb "cli" || exit 1 &
    else
        warn ".deb creation manually skipped"
    fi
    wait
}



pipeline