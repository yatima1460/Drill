#!/bin/bash

DEB_PACKAGE_NAME="drill-search"
EXECUTABLE_IN_OPT="drill-gtk.elf"



if [ -f ../../$EXECUTABLE_IN_OPT ]; then
    echo $EXECUTABLE_IN_OPT executable found
else
    echo No $EXECUTABLE_IN_OPT executable found!
    echo Starting build...

    cd ../../
    cd source/cli
    dub build -b release --parallel --arch=x86_64
    cd ../../

    cd source/gtkui
    dub build -b release --parallel --arch=x86_64
    cd ../../

    cd tools/deb
fi

rm -rf DEBFILE

# add binary for /usr/bin
mkdir -p DEBFILE/usr/bin
echo \#!/bin/bash > DEBFILE/usr/bin/$DEB_PACKAGE_NAME
echo /opt/$DEB_PACKAGE_NAME/$EXECUTABLE_IN_OPT >> DEBFILE/usr/bin/$DEB_PACKAGE_NAME
chmod +x DEBFILE/usr/bin/$DEB_PACKAGE_NAME

# add assets data
mkdir -p DEBFILE/opt/$DEB_PACKAGE_NAME/
cp ../../$EXECUTABLE_IN_OPT DEBFILE/opt/$DEB_PACKAGE_NAME/$EXECUTABLE_IN_OPT
cp -r ../../assets DEBFILE/opt/$DEB_PACKAGE_NAME/
#chmod -R 700 DEBFILE/opt/drill
chmod +x DEBFILE/opt/$DEB_PACKAGE_NAME/$EXECUTABLE_IN_OPT


#add deb metadata
mkdir DEBFILE/DEBIAN
cp control DEBFILE/DEBIAN

if [ -f ../../DRILL_VERSION ]; then
    cp ../../DRILL_VERSION DEBFILE/opt/$DEB_PACKAGE_NAME/
    echo Version: $(cat ../../DRILL_VERSION) >> DEBFILE/DEBIAN/control
    cat DEBFILE/DEBIAN/control
    echo Building .deb for version $(cat ../../DRILL_VERSION)
else
    echo No Drill version found! Using 0.0.0
    echo Version: 0.0.0 >> DEBFILE/DEBIAN/control
fi


# add desktop file
mkdir -p DEBFILE/usr/share/applications
desktop-file-validate $DEB_PACKAGE_NAME.desktop
cp $DEB_PACKAGE_NAME.desktop DEBFILE/usr/share/applications/

# add icon
mkdir -p DEBFILE/usr/share/icons/$DEB_PACKAGE_NAME
#mkdir -p DEBFILE/usr/share/app-install/icons/

cp ../../assets/icon.png DEBFILE/usr/share/icons/$DEB_PACKAGE_NAME/drill.png
#cp ../../assets/icon.svg DEBFILE/usr/share/app-install/icons/drill.svg


# build the .deb file
dpkg-deb --build DEBFILE
mv DEBFILE.deb $EXECUTABLE_IN_OPT.deb
