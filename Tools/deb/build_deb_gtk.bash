#!/bin/bash


# .deb
export CREATE_DEB_GTK=true
export DEB_GTK_PACKAGE_NAME="drill-search-gtk"
export CREATE_DEB_CLI=true
export DEB_CLI_PACKAGE_NAME="drill-search-cli"

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

deb() {
    info "Starting creation of .deb for $1..."
    if [[ $1 == "gtk" ]]; then
        DEB_PACKAGE_NAME=$DEB_GTK_PACKAGE_NAME
    fi
    if [[ $1 == "cli" ]]; then
        DEB_PACKAGE_NAME=$DEB_CLI_PACKAGE_NAME  
    fi
    
   
    if [ -f ../../Build/"$DEB_PACKAGE_NAME" ]; then
        info "$DEB_PACKAGE_NAME   executable found"
    else
        error "No $DEB_PACKAGE_NAME   executable found!"
        exit 1
    fi


    rm -rf DEBFILE/"$1"/

    # install binary redirect for /usr/bin and set it executable
    mkdir -p DEBFILE/"$1"/usr/bin
    cp "drill-search" DEBFILE/"$1"/usr/bin/$DEB_PACKAGE_NAME
    echo    /opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME" "\$@" >> DEBFILE/"$1"/usr/bin/$DEB_PACKAGE_NAME
    chmod   +x                                           DEBFILE/"$1"/usr/bin/$DEB_PACKAGE_NAME
    

    ## install drill in /opt

    # add assets
    mkdir   -p DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/
    cp      ../../Build/"$DEB_PACKAGE_NAME"            DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME"
    cp      -r ../../Assets                     DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/
    chmod   +x                                  DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/"$DEB_PACKAGE_NAME"

    mkdir DEBFILE/"$1"/DEBIAN
    cp control-"$1" DEBFILE/"$1"/DEBIAN/control

    # append .deb version to the .deb metadata
    # and add DRILL_VERSION to /opt



    if [ -f ../../DRILL_VERSION ]; then
        cp ../../DRILL_VERSION DEBFILE/"$1"/opt/$DEB_PACKAGE_NAME/
        echo Version: "$(cat ../../DRILL_VERSION)" >> DEBFILE/"$1"/DEBIAN/control
        cat DEBFILE/"$1"/DEBIAN/control
        echo Building .deb for version "$(cat ../../DRILL_VERSION)"
        export DRILL_VERSION=$(cat ../../DRILL_VERSION)
    else
        echo No Drill version found! Using 0.0.0
        echo Version: 0.0.0 >> DEBFILE/"$1"/DEBIAN/control
        export DRILL_VERSION="LOCAL_BUILD"
    fi


    if [[ $1 == "gtk" ]]; then
        # add desktop file
        mkdir -p DEBFILE/"$1"/usr/share/applications
        desktop-file-validate drill-search-gtk.desktop
        cp drill-search-gtk.desktop DEBFILE/gtk/usr/share/applications/

        # add icon
        mkdir -p DEBFILE/"$1"/usr/share/pixmaps
        cp drill-search-gtk.svg DEBFILE/gtk/usr/share/pixmaps/drill-search-gtk.svg
    fi

    # build the .deb file

    if dpkg-deb --build DEBFILE/"$1"/; then
        info ".deb built correctly"
    else
        error "Building .deb failed"
        exit 1
    fi


    if mv DEBFILE/"$1".deb Drill-"$1"-linux-$DRILL_VERSION-x86_64.deb; then
        info "Drill-$1-linux-$DRILL_VERSION-x86_64.deb moved to build"
    else
        error "Drill-$1-linux-$DRILL_VERSION-x86_64.deb can't be moved to build"
        exit 1
    fi

    
}


if $CREATE_DEB_GTK; then
    deb "gtk" || exit 1 &
else
    warn ".deb UI creation skipped"
fi
if $CREATE_DEB_CLI; then
    deb "cli" || exit 1 &
else
    warn ".deb CLI creation skipped"
fi      