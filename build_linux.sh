#!/bin/bash

#==== DRILL BUILD SETTINGS ====

VERBOSE=false



BUILD_CLI=true
BUILD_GTK=true

APPDIR_CLI=true
APPDIR_GTK=true

CREATE_APPIMAGE=true

CREATE_DEB=true
DEB_PACKAGE_NAME="drill-search"


#CREATE_ZIP=true
#CREATE_GTK=true

#==============================

info () {
    echo "\033[32m[DRILL BUILD][INFO]: $1\033[0m"
}

warn() {
    echo "\033[33m[DRILL BUILD][WARNING]: $1\033[0m"
}

error() {
    echo "\033[31m[DRILL BUILD][ERROR]: $1\033[0m"
    exit 1
}


if $VERBOSE; then 
    info "Verbose mode on"
    #OUTPUT=1>&1
else
    if [ -z "$TRAVIS_TAG" ]; then
        warn "Verbose mode off"
        OUTPUT=&>/dev/null
        export OUTPUT
    else
        warn "Verbose mode forcefully enabled because this is a travis build"
    fi
fi


# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
ctrl_c() {
    error "user manually stopped build with Ctrl-C"
    # stop children jobs
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
    export TRAVIS_TAG="0.0.0"
    export DRILL_VERSION=$TRAVIS_TAG
    warn "Not a travis build, TRAVIS_BUILD_NUMBER not set, will use '$DRILL_VERSION' as version string"
else
    info "This is a Travis build"
    export TRAVIS_TAG="1.$TRAVIS_BUILD_NUMBER"
    export DRILL_VERSION=$TRAVIS_TAG
fi

# write version to file
# it will be included in all packaged versions
echo -n $DRILL_VERSION > DRILL_VERSION

if dub --version; then
    info "D environment found"
else
    warn "D environment missing, will try to install dlang"
    curl -fsS https://dlang.org/install.sh | bash -s dmd $OUTPUT
    if [ $? -eq 0 ]; then
        info "D environment installed correctly"
    else
        error "D environment installation failed"
        exit 1
    fi
    . ~/dlang/dmd-2.086.0/activate;
    if [ $? -eq 0 ]; then
        info "D environment activated correctly"
    else
        error "D environment can't be activated"
        exit 1
    fi
fi


package() {
    7z a -tzip Drill-$1-linux-$DRILL_VERSION.zip assets drill-$1.elf DRILL_VERSION  $OUTPUT
    if [ $? -eq 0 ]; then
        info "Zipping of $1 done"
        mv Drill-$1-linux-$DRILL_VERSION.zip build $OUTPUT
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
    cd tools/appimage $OUTPUT
    wget -c https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage $OUTPUT
    chmod +x pkg2appimage
    ./pkg2appimage $1.yml $OUTPUT
    if [ $? -eq 0 ]; then
        info "AppImage build done"
    else
        error "AppImage build failed"
    fi
    cd ../../ $OUTPUT
    mv tools/appimage/out/*.AppImage build/Drill-$1-linux-$DRILL_VERSION.AppImage  $OUTPUT
    chmod +x build/Drill-$1-linux-$DRILL_VERSION.AppImage  $OUTPUT
    rmdir tools/appimage/out  $OUTPUT
    rm tools/appimage/pkg2appimage  $OUTPUT
}


build() {
    info "Starting build of $1..."
    cd $1 $OUTPUT
    
    if $VERBOSE; then
        dub build -b release --parallel --arch=x86_64 $OUTPUT
        result=$?
    else
        dub build -b release --parallel --arch=x86_64 --vquiet $OUTPUT
        result=$?
    fi
    if [ $result -eq 0 ]; then
        info "$1 built correctly"
    else
        error "Building $1... failed"
        exit 1
    fi
    cd - $OUTPUT
}

appdir() {
    mkdir               build/$1
    cp -r assets        build/$1
    cp drill-$1.elf     build/$1
    cp DRILL_VERSION    build/$1
}

deb() {
    info "Starting creation of .deb for $1..."
    cd tools/deb $OUTPUT
    EXECUTABLE_IN_OPT="drill-$1.elf"
    if [ -f ../../$EXECUTABLE_IN_OPT ]; then
        info "$EXECUTABLE_IN_OPT executable found"
    else
        error "No $EXECUTABLE_IN_OPT executable found!"
        exit 1
    fi

    rm -rf DEBFILE $OUTPUT

    # install binary redirect for /usr/bin and set it executable
    mkdir -p DEBFILE/usr/bin
    echo    #!/bin/bash                               >  DEBFILE/usr/bin/$DEB_PACKAGE_NAME
    echo    /opt/$DEB_PACKAGE_NAME/$EXECUTABLE_IN_OPT >> DEBFILE/usr/bin/$DEB_PACKAGE_NAME
    chmod   +x                                           DEBFILE/usr/bin/$DEB_PACKAGE_NAME

    ## install drill in /opt

    # add assets
    mkdir   -p DEBFILE/opt/$DEB_PACKAGE_NAME/
    cp      ../../$EXECUTABLE_IN_OPT            DEBFILE/opt/$DEB_PACKAGE_NAME/$EXECUTABLE_IN_OPT
    cp      -r ../../assets                     DEBFILE/opt/$DEB_PACKAGE_NAME/
    chmod   +x                                  DEBFILE/opt/$DEB_PACKAGE_NAME/$EXECUTABLE_IN_OPT

    mkdir DEBFILE/DEBIAN
    cp control DEBFILE/DEBIAN/control

    # append .deb version to the .deb metadata
    # and add DRILL_VERSION to /opt



    if [ -f ../../DRILL_VERSION ]; then
        cp ../../DRILL_VERSION DEBFILE/opt/$DEB_PACKAGE_NAME/
        echo Version: $(cat ../../DRILL_VERSION) >> DEBFILE/DEBIAN/control
        cat DEBFILE/DEBIAN/control $OUTPUT
        echo Building .deb for version $(cat ../../DRILL_VERSION)
        export DRILL_VERSION=$(cat ../../DRILL_VERSION)
    else
        echo No Drill version found! Using 0.0.0
        echo Version: 0.0.0 >> DEBFILE/DEBIAN/control
        export DRILL_VERSION="LOCAL_BUILD"
    fi



    # add desktop file
    mkdir -p DEBFILE/usr/share/applications
    desktop-file-validate $DEB_PACKAGE_NAME.desktop
    cp $DEB_PACKAGE_NAME.desktop DEBFILE/usr/share/applications/

    # add icon
    mkdir -p DEBFILE/usr/share/icons/$DEB_PACKAGE_NAME
    cp ../../assets/icon.png DEBFILE/usr/share/icons/$DEB_PACKAGE_NAME/drill.png
    #cp ../../assets/icon.svg DEBFILE/usr/share/app-install/icons/drill.svg

    # build the .deb file
    dpkg-deb --build DEBFILE $OUTPUT
    if [ $? -eq 0 ]; then
        info ".deb built correctly"
    else
        error "Building .deb failed"
        exit 1
    fi

    mv DEBFILE.deb ../../build/Drill-$1-linux-$DRILL_VERSION.deb $OUTPUT
    if [ $? -eq 0 ]; then
        info ".deb moved to build"
    else
        error ".deb can't be moved to build"
        exit 1
    fi

    cd ../../ $OUTPUT
}

pipeline() {
    if $BUILD_CLI || $BUILD_GTK; then
        build "source/core/datefmt" || exit 1 &
        build "source/gtkui/GtkD"   || exit 1 &
        wait

        build "source/core"         || exit 1 &
        wait

        if $BUILD_CLI; then
        build "source/cli" || exit 1 &
        else
            warn "Skipping build CLI"
        fi
        if $BUILD_GTK; then
            build "source/gtkui" || exit 1 &
        else
            warn "Skipping build GTK"
        fi
        wait

        if $APPDIR_CLI; then
            appdir "cli" || exit 1 &
        else
            warn "Skipping creating appdir CLI"
        fi
        if $APPDIR_GTK; then
            appdir "gtk"  || exit 1 &
        else
            warn "Skipping creating appdir GTK"
        fi
        if $APPDIR_CLI; then
            package "cli" || exit 1 &
        fi
        if $APPDIR_GTK; then
            package "gtk" || exit 1 &
        fi
    else
        warn "Skipping build manually"
    fi
    if $CREATE_APPIMAGE; then
        appimage "gtk" || exit 1 &
    else
        warn ".AppImage creation manually skipped"
    fi
    if $CREATE_DEB; then
        deb "gtk" || exit 1 &
    else
        warn ".deb creation manually skipped"
    fi
    wait
    info "All done."
}



pipeline