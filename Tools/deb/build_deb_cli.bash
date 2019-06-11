#!/bin/bash


# .deb
export DEB_PACKAGE_NAME="drill-search-cli"
export CLI_BUILD_DIR="Drill-CLI-linux-x86_64-release"

#===== LOGGING FUNCTIONS
info () {
    echo -e "\033[32m[DEB BUILD][INFO]: $1\033[0m"
}

warn() {
    echo -e "\033[33m[DEB BUILD][WARNING]: $1\033[0m"
}

error() {
    echo -e "\033[31m[DEB BUILD][ERROR]: $1\033[0m"
    exit 1
}
#========================

export BUILD_DIR=../../Source/Frontend/CLI/Build/"$CLI_BUILD_DIR"

if [ -f $BUILD_DIR/"$DEB_PACKAGE_NAME" ]; then
    info "$DEB_PACKAGE_NAME   executable found"
else
    error "No $DEB_PACKAGE_NAME   executable found!"
    exit 1
fi

# remove old temp files
rm -rf DEBFILE/CLI/

# install binary redirect for /usr/bin and set it executable
mkdir -p DEBFILE/CLI/usr/bin
cp "drill-search" DEBFILE/CLI/usr/bin/$DEB_PACKAGE_NAME
echo    /opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME" "\$@" >> DEBFILE/CLI/usr/bin/$DEB_PACKAGE_NAME
chmod   +x                                           DEBFILE/CLI/usr/bin/$DEB_PACKAGE_NAME

# install in /opt
mkdir -p DEBFILE/CLI/opt/
cp      -r "$BUILD_DIR"     DEBFILE/CLI/opt/$DEB_PACKAGE_NAME
chmod   +x                  DEBFILE/CLI/opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME"

# make .deb metadata
mkdir DEBFILE/CLI/DEBIAN
cp control-cli DEBFILE/CLI/DEBIAN/control

# append .deb version to the .deb metadata
# and add DRILL_VERSION to /opt
if [ -f ../../DRILL_VERSION ]; then
    cp ../../DRILL_VERSION DEBFILE/CLI/opt/$DEB_PACKAGE_NAME/
    echo Version: "$(cat ../../DRILL_VERSION)" >> DEBFILE/CLI/DEBIAN/control
    cat DEBFILE/CLI/DEBIAN/control
    echo Building .deb for version "$(cat ../../DRILL_VERSION)"
    export DRILL_VERSION=$(cat ../../DRILL_VERSION)
else
    echo No Drill version found! Using 0.0.0
    echo Version: 0.0.0 >> DEBFILE/CLI/DEBIAN/control
    export DRILL_VERSION="LOCAL_BUILD"
fi

# build the .deb file
if dpkg-deb --build DEBFILE/CLI/; then
    info ".deb built correctly"
else
    error "Building .deb failed"
    exit 1
fi

if mv DEBFILE/CLI.deb Drill-CLI-linux-$DRILL_VERSION-x86_64.deb; then
    info "Drill-CLI-linux-$DRILL_VERSION-x86_64.deb moved to build"
else
    error "Drill-CLI-linux-$DRILL_VERSION-x86_64.deb can't be moved to build"
    exit 1
fi