#!/bin/bash


# .deb
DEB_PACKAGE_NAME="drill-search-gtk"
GTK_BUILD_DIR="Drill-GTK-linux-x86_64-release"
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

export BUILD_DIR=../../Source/Frontend/GTK/Build/"$GTK_BUILD_DIR"

if [ -f $BUILD_DIR/"$DEB_PACKAGE_NAME" ]; then
    info "$DEB_PACKAGE_NAME   executable found"
else
    error "No $DEB_PACKAGE_NAME   executable found in $BUILD_DIR/$DEB_PACKAGE_NAME !"
    exit 1
fi

# remove old temp files
rm -rf DEBFILE/GTK/

# install binary redirect for /usr/bin and set it executable
mkdir -p DEBFILE/GTK/usr/bin
cp "drill-search" DEBFILE/GTK/usr/bin/$DEB_PACKAGE_NAME
echo    /opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME" "\$@" >> DEBFILE/GTK/usr/bin/$DEB_PACKAGE_NAME
chmod   +x                                           DEBFILE/GTK/usr/bin/$DEB_PACKAGE_NAME

# install in /opt
mkdir -p DEBFILE/GTK/opt/
cp      -r "$BUILD_DIR"     DEBFILE/GTK/opt/$DEB_PACKAGE_NAME
chmod   +x                  DEBFILE/GTK/opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME"

# make .deb metadata
mkdir DEBFILE/GTK/DEBIAN
cp control-gtk DEBFILE/GTK/DEBIAN/control

# append .deb version to the .deb metadata
# and add DRILL_VERSION to /opt
echo Version: $DRILL_VERSION >> DEBFILE/GTK/DEBIAN/control

 # add desktop file
mkdir -p DEBFILE/GTK/usr/share/applications
desktop-file-validate drill-search-gtk.desktop
cp drill-search-gtk.desktop DEBFILE/GTK/usr/share/applications/

# add icon
mkdir -p DEBFILE/GTK/usr/share/pixmaps
cp drill-search-gtk.svg DEBFILE/GTK/usr/share/pixmaps/drill-search-gtk.svg

# build the .deb file
if dpkg-deb --build DEBFILE/GTK/; then
    info ".deb built correctly"
else
    error "Building .deb failed"
    exit 1
fi

mkdir Build
if mv DEBFILE/GTK.deb Build/Drill-GTK-linux-x86_64-release-$DRILL_VERSION.deb; then
    info "Drill-GTK-linux-x86_64-release-$DRILL_VERSION.deb built"
else
    error "Drill-GTK-linux-x86_64-release-$DRILL_VERSION.deb can't be moved to build"
    exit 1
fi