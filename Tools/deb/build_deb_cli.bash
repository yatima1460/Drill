#!/bin/bash


# .deb
DEB_PACKAGE_NAME="drill-search-cli"
CLI_BUILD_DIR="Drill-CLI-linux-x86_64-release"
BUILD_DIR=../../Source/Frontend/CLI/Build/"$CLI_BUILD_DIR"
DRILL_VERSION=$(cat ../../DRILL_VERSION)

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


if [ -f $BUILD_DIR/"$DEB_PACKAGE_NAME" ]; then
    info "$DEB_PACKAGE_NAME   executable found"
else
    error "No $DEB_PACKAGE_NAME   executable found!"
    exit 1
fi
#========================

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

# append version to the .deb metadata
echo Version: $DRILL_VERSION >> DEBFILE/CLI/DEBIAN/control

# build the .deb file
if dpkg-deb --build DEBFILE/CLI/; then
    info ".deb built correctly"
else
    error "Building .deb failed"
    exit 1
fi

mkdir Build
if mv DEBFILE/CLI.deb Build/Drill-CLI-linux-x86_64-release-$DRILL_VERSION.deb; then
    info "Drill-CLI-linux-x86_64-release-$DRILL_VERSION.deb moved to build"
else
    error "Drill-CLI-linux-x86_64-release-$DRILL_VERSION.deb can't be moved to build"
    exit 1
fi