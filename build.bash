#!/bin/bash

#==== DRILL BUILD SETTINGS ====

export OS=linux #windows, osx
export VERBOSE=false

# CLI and UI are both standalone and use source/core
# you can have both true or one true
# or both false if you just want to package an already built binary
export BUILD_CLI=false
export BUILD_UI=true

# create a portable directory in build
# just a folder with the binary and assets
export APPDIR_CLI=false
export APPDIR_UI=false

# create a zip of the portable directory in build
# this is independent, you can create a .zip without creating the APPDIR
export ZIPDIR_CLI=false
export ZIPDIR_UI=false



###### WINDOWS ONLY ######
#export CREATE_INSTALLER=false



# FIXES FOR WINDOWS
export BUILD_DIR="$PWD"
export ARCH=x86_64
if [[ $OS == "windows" ]]; then unset ARCH && export ARCH=x86; fi


###### LINUX ONLY ######

# .deb
export CREATE_DEB_UI=true
export DEB_UI_PACKAGE_NAME="drill-search"
export CREATE_DEB_CLI=true
export DEB_CLI_PACKAGE_NAME="drill-search-cli"

# .AppImage
# https://appimage.org/
export CREATE_APPIMAGE=false

# .flatpak
#export CREATE_FLATPAK=false

# .snap
#export CREATE_SNAP=false

#==============================



#===== LOGGING FUNCTIONS
info () {
    echo -e "\033[32m[DRILL BUILD][INFO]: $1\033[0m"
}

warn() {
    echo -e "\033[33m[DRILL BUILD][WARNING]: $1\033[0m"
}

error() {
    echo -e "\033[31m[DRILL BUILD][ERROR]: $1\033[0m"
    exit 1
}



#===== TRAVIS FUNCTIONS


# if TRAVIS_OS_NAME is set, override OS to TRAVIS_OS_NAME
if [[ -n $TRAVIS_OS_NAME ]]; then
    unset $OS
    export OS="$TRAVIS_OS_NAME"
    warn "Travis OS override set to $TRAVIS_OS_NAME"
fi

info "Current OS for this build is: $OS"

if [[ $TRAVIS_OS_NAME == "linux" ]]; then
    if ! $BUILD_CLI; then warn "Travis override: BUILD_CLI=true"; fi
    BUILD_CLI=true
    if ! $BUILD_UI; then warn "Travis override: BUILD_CLI=true"; fi
    BUILD_UI=true
    if $APPDIR_CLI; then warn "Travis override: APPDIR_CLI=false"; fi
    APPDIR_CLI=false
    if $APPDIR_UI; then warn "Travis override: APPDIR_UI=false"; fi
    APPDIR_UI=false
    if ! $ZIPDIR_CLI; then warn "Travis override: ZIPDIR_CLI=true"; fi
    ZIPDIR_CLI=true
    if ! $ZIPDIR_UI; then warn "Travis override: ZIPDIR_CLI=true"; fi
    ZIPDIR_UI=true
    if ! $CREATE_APPIMAGE; then warn "Travis override: CREATE_APPIMAGE=true"; fi
    CREATE_APPIMAGE=true
    if ! $CREATE_DEB_UI; then warn "Travis override: CREATE_DEB_UI=true"; fi
    CREATE_DEB_UI=true
    if ! $CREATE_DEB_CLI; then warn "Travis override: CREATE_DEB_CLI=true"; fi
    CREATE_DEB_CLI=true
fi
if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    if ! $BUILD_CLI; then warn "Travis override: BUILD_CLI=true"; fi
    BUILD_CLI=true
    if ! $BUILD_UI; then warn "Travis override: BUILD_CLI=true"; fi
    BUILD_UI=true
    if $APPDIR_CLI; then warn "Travis override: APPDIR_CLI=false"; fi
    APPDIR_CLI=false
    if $APPDIR_UI; then warn "Travis override: APPDIR_UI=false"; fi
    APPDIR_UI=false
    if ! $ZIPDIR_CLI; then warn "Travis override: ZIPDIR_CLI=true"; fi
    ZIPDIR_CLI=true
    if ! $ZIPDIR_UI; then warn "Travis override: ZIPDIR_CLI=true"; fi
    ZIPDIR_UI=true
    if $CREATE_APPIMAGE; then warn "Travis override: CREATE_APPIMAGE=false"; fi
    CREATE_APPIMAGE=false
    if $CREATE_DEB_UI; then warn "Travis override: CREATE_DEB_UI=false"; fi
    CREATE_DEB_UI=false
    if $CREATE_DEB_CLI; then warn "Travis override: CREATE_DEB_CLI=false"; fi
    CREATE_DEB_CLI=false
fi
if [[ $TRAVIS_OS_NAME == "osx" ]]; then
    if ! $BUILD_CLI; then warn "Travis override: BUILD_CLI=true"; fi
    BUILD_CLI=true
    if ! $BUILD_UI; then warn "Travis override: BUILD_CLI=true"; fi
    BUILD_UI=true
    if $APPDIR_CLI; then warn "Travis override: APPDIR_CLI=false"; fi
    APPDIR_CLI=false
    if $APPDIR_UI; then warn "Travis override: APPDIR_UI=false"; fi
    APPDIR_UI=false
    if ! $ZIPDIR_CLI; then warn "Travis override: ZIPDIR_CLI=true"; fi
    ZIPDIR_CLI=true
    if ! $ZIPDIR_UI; then warn "Travis override: ZIPDIR_CLI=true"; fi
    ZIPDIR_UI=true
    if $CREATE_APPIMAGE; then warn "Travis override: CREATE_APPIMAGE=false"; fi
    CREATE_APPIMAGE=false
    if $CREATE_DEB_UI; then warn "Travis override: CREATE_DEB_UI=false"; fi
    CREATE_DEB_UI=false
    if $CREATE_DEB_CLI; then warn "Travis override: CREATE_DEB_CLI=false"; fi
    CREATE_DEB_CLI=false
fi

if $VERBOSE; then 
    info "Verbose mode on"
    #OUTPUT=1>&1
else
    if [ -z "$TRAVIS_OS_NAME" ]; then
        warn "Verbose mode off"
        OUTPUT=&>/dev/null
        export OUTPUT
    else
        warn "Travis override: VERBOSE=true"
    fi
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


#===== CTRL-C EVENT

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
ctrl_c() {
    error "user stopped build with Ctrl-C"
    # stop children jobs
    pkill -P $$
    exit 2
}



#===== CLEAR PREVIOUS BUILD
if rm -rf build; then
    info "build directory cleared"
else
    error "can't clear build directory"
    exit 1
fi


if mkdir -p build; then
    info "build directory created"
else
    error "can't create build directory"
    exit 1
fi







# write version to file
# it will be included in all packaged versions
echo -n "$DRILL_VERSION" > DRILL_VERSION


#===== D ENVIRONMENT CHECKS

if dub --version && dmd --version; then
    info "D environment found"
else
    warn "D environment missing, will try to install dlang"
    if [[ $OS == "linux" ]]; then
        
        if curl -fsS https://dlang.org/install.sh | bash -s dmd $OUTPUT; then
            info "D environment installed correctly"
        else
            error "D environment installation failed"
            exit 1
        fi
        
        if . ~/dlang/dmd-2.086.0/activate; then
            info "D environment activated correctly"
        else
            error "D environment can't be activated"
            exit 1
        fi
    fi
    if [[ $OS == "osx" ]]; then
        error "you need to install dmd and dub using homebrew"
        exit 1
    fi 
    if [[ $OS == "windows" ]]; then
        wget http://downloads.dlang.org/nightlies/dmd-master/dmd.master.windows.7z
        7z x dmd.master.windows.7z
        dmd2/windows/bin/dub --version
    fi 
fi

#===== CREATE A PORTABLE .ZIP FILE
package() {
    local EXE_NAME=drill-$1
    if [[ $OS == "windows" ]]; then EXE_NAME=drill-$1.exe; fi
    
    
    if 7z a -tzip Drill-"$1"-"$OS"-"$DRILL_VERSION"-"$ARCH".zip assets "$EXE_NAME" DRILL_VERSION  $OUTPUT; then
        info "Zipping of $1 done"
        
        if mv Drill-"$1"-"$OS"-"$DRILL_VERSION"-"$ARCH".zip build $OUTPUT; then
            info "Drill-$1-$OS-$DRILL_VERSION-x86_64.zip moved to build folder"
        else
            error "Drill-$1-$OS-$DRILL_VERSION-x86_64.zip could not be moved to build folder"
        fi
    else
        rm Drill-"$1"-"$OS"-"$DRILL_VERSION"-"$ARCH".zip
        error "Zipping of $1 could not find some files"
        exit 1
    fi
}

#===== DOWNLOAD DEPENDENCIES AND CREATE THE APPIMAGE 
# $1 = project subfolder in source 
appimage() {
    cd tools/appimage $OUTPUT || exit
    wget -c https://raw.githubusercontent.com/AppImage/pkg2appimage/master/pkg2appimage $OUTPUT
    chmod +x pkg2appimage
    
    if ./pkg2appimage "$1".yml $OUTPUT; then
        info "AppImage build done"
    else
        error "AppImage build failed"
    fi
    cd ../../ $OUTPUT || exit
    mv tools/appimage/out/*.AppImage build/Drill-"$1"-linux-"$DRILL_VERSION"-x86_64.AppImage  $OUTPUT
    chmod +x build/Drill-"$1"-linux-"$DRILL_VERSION"-x86_64.AppImage  $OUTPUT
    rmdir tools/appimage/out  $OUTPUT
    rm tools/appimage/pkg2appimage  $OUTPUT
}

#===== BUILD
# $1 = project path 
build() {
    info "Starting build of $1..."
    cd "$1" $OUTPUT || exit
    if [[ $OS == "linux" || $OS == "osx" ]]; then
        
        if dub build -b release --parallel --arch=x86_64 $OUTPUT; then
            info "$1 built correctly"
        else
            error "Building $1... failed"
            exit 1
        fi
    fi
    if [[ $OS == "windows" ]]; then
        
        if "$BUILD_DIR"/dmd2/windows/bin/dub build -b release --parallel --arch=x86 $OUTPUT; then
            info "$1 built correctly"
        else
            error "Building $1... failed"
            exit 1
        fi
    fi

    cd - $OUTPUT || exit
}

appdir() {
    mkdir               build/"$1"
    cp -r assets        build/"$1"
    cp drill-"$1"       build/"$1"
    cp DRILL_VERSION    build/"$1"
}

deb() {
    info "Starting creation of .deb for $1..."
    if [[ $1 == "ui" ]]; then
        DEB_PACKAGE_NAME=$DEB_UI_PACKAGE_NAME
    fi
    if [[ $1 == "cli" ]]; then
        DEB_PACKAGE_NAME=$DEB_CLI_PACKAGE_NAME  
    fi
    cd tools/deb $OUTPUT || exit
    EXECUTABLE_IN_OPT="drill-$1"
    if [ -f ../../"$EXECUTABLE_IN_OPT" ]; then
        info "$EXECUTABLE_IN_OPT executable found"
    else
        error "No $EXECUTABLE_IN_OPT executable found!"
        exit 1
    fi


    rm -rf DEBFILE/"$1"/

    # install binary redirect for /usr/bin and set it executable
    mkdir -p DEBFILE/"$1"/usr/bin
    echo    #!/bin/bash                                     >  DEBFILE/usr/bin/$DEB_PACKAGE_NAME
    echo    /opt/$DEB_PACKAGE_NAME/"$EXECUTABLE_IN_OPT" "\$@" >> DEBFILE/"$1"/usr/bin/$DEB_PACKAGE_NAME
    chmod   +x                                           DEBFILE/"$1"/usr/bin/$DEB_PACKAGE_NAME

    ## install drill in /opt

    # add assets
    mkdir   -p DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/
    cp      ../../"$EXECUTABLE_IN_OPT"            DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/"$EXECUTABLE_IN_OPT"
    cp      -r ../../assets                     DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/
    chmod   +x                                  DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/"$EXECUTABLE_IN_OPT"

    mkdir DEBFILE/"$1"/DEBIAN
    cp control-"$1" DEBFILE/"$1"/DEBIAN/control

    # append .deb version to the .deb metadata
    # and add DRILL_VERSION to /opt



    if [ -f ../../DRILL_VERSION ]; then
        cp ../../DRILL_VERSION DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/
        echo Version: "$(cat ../../DRILL_VERSION)" >> DEBFILE/"$1"/DEBIAN/control
        cat DEBFILE/"$1"/DEBIAN/control $OUTPUT
        echo Building .deb for version "$(cat ../../DRILL_VERSION)"
        export DRILL_VERSION=$(cat ../../DRILL_VERSION)
    else
        echo No Drill version found! Using 0.0.0
        echo Version: 0.0.0 >> DEBFILE/"$1"/DEBIAN/control
        export DRILL_VERSION="LOCAL_BUILD"
    fi


    if [[ $1 == "ui" ]]; then
        # add desktop file
        mkdir -p DEBFILE/"$1"/usr/share/applications
        desktop-file-validate $DEB_PACKAGE_NAME.desktop
        cp $DEB_PACKAGE_NAME.desktop DEBFILE/"$1"/usr/share/applications/

        # add icon
        mkdir -p DEBFILE/"$1"/usr/share/pixmaps
        cp ../../assets/icon.svg DEBFILE/"$1"/usr/share/pixmaps/"$DEB_PACKAGE_NAME".svg
        #cp ../../assets/icon.svg DEBFILE/usr/share/app-install/icons/drill.svg
    fi

    # build the .deb file
    
    if dpkg-deb --build DEBFILE/"$1"/ $OUTPUT; then
        info ".deb built correctly"
    else
        error "Building .deb failed"
        exit 1
    fi

    
    if mv DEBFILE/"$1".deb ../../build/Drill-"$1"-linux-$DRILL_VERSION-x86_64.deb $OUTPUT; then
        info "Drill-$1-linux-$DRILL_VERSION-x86_64.deb moved to build"
    else
        error "Drill-$1-linux-$DRILL_VERSION-x86_64.deb can't be moved to build"
        exit 1
    fi

    cd ../../ $OUTPUT || exit
}

pipeline() {
    if $BUILD_CLI || $BUILD_UI; then
        build "source/core/datefmt-1.0.3" || exit 1 &
        build "source/ui/GtkD-3.8.5"   || exit 1 &
        wait

        build "source/core"         || exit 1 &
        wait

        if $BUILD_CLI; then
            build "source/cli" || exit 1 &
        else
            warn "Skipping build CLI"
        fi
        if $BUILD_UI; then
            build "source/ui" || exit 1 &
        else
            warn "Skipping build UI"
        fi
        wait

        if $APPDIR_CLI; then
            appdir "cli" || exit 1 &
        else
            warn "Skipping creating appdir CLI"
        fi
        if $APPDIR_UI; then
            appdir "ui"  || exit 1 &
        else
            warn "Skipping creating appdir UI"
        fi
        if $ZIPDIR_CLI; then
            package "cli" || exit 1 &
        fi
        if $ZIPDIR_UI; then
            package "ui" || exit 1 &
        fi
    else
        warn "Skipping build manually"
    fi
    if $CREATE_APPIMAGE; then
        appimage "ui" || exit 1 &
    else
        warn ".AppImage creation skipped"
    fi
    if $CREATE_DEB_UI; then
        deb "ui" || exit 1 &
    else
        warn ".deb UI creation skipped"
    fi
    if $CREATE_DEB_CLI; then
        deb "cli" || exit 1 &
    else
        warn ".deb CLI creation skipped"
    fi       
    wait
    info "Build folder list:"
    find "build" -maxdepth 1 -not -type d
    info "All done."
    exit 0 
}



pipeline




# TODO: windows build
# wget http://downloads.dlang.org/nightlies/dmd-master/dmd.master.windows.7z;
# 7z x dmd.master.windows.7z;
# git clone https://github.com/yatima1460/GTK3-windows-32bit;
# cd source/cli
# ../../dmd2/windows/bin/dub build -b release --parallel --force --arch=x86
# cd ../../
# 7z a -tzip ../../build/Drill-cli-windows-$TRAVIS_TAG-x86.zip assets drill-cli.exe;
# cd source/gtkui
# ../../dmd2/windows/bin/dub build -b release --parallel --force --arch=x86;
# cd ../../
# mv GTK3-windows-32bit/*.dll .;
# 7z a -tzip ../../build/Drill-gtk-windows-$TRAVIS_TAG-x86.zip assets drill-gtk.exe DRILL_VERSION *.dll;
