#!/bin/bash




if [ -f ../../Drill-GTK ]; then
    echo Drill-GTK executable found
else
    echo No Drill-GTK executable found!
    exit 1
fi

rm -rf DEBFILE

# add binary
mkdir -p DEBFILE/usr/bin
cp drill-search DEBFILE/usr/bin
chmod +x DEBFILE/usr/bin/drill-search

# add drill data
mkdir -p DEBFILE/opt/drill-search/
cp ../../Drill-GTK DEBFILE/opt/drill-search/Drill-GTK
cp -r ../../assets DEBFILE/opt/drill-search/
#chmod -R 700 DEBFILE/opt/drill
chmod +x DEBFILE/opt/drill-search/Drill-GTK


#add deb metadata
mkdir DEBFILE/DEBIAN
cp control DEBFILE/DEBIAN

if [ -f ../../DRILL_VERSION ]; then
    cp ../../DRILL_VERSION DEBFILE/opt/drill-search/
    echo Version: $(cat ../../DRILL_VERSION) >> DEBFILE/DEBIAN/control
    cat DEBFILE/DEBIAN/control
    echo Building .deb for version $(cat ../../DRILL_VERSION)
else
    echo No Drill version found!
    echo Version: 0.0.0 >> DEBFILE/DEBIAN/control
fi


# add desktop file
mkdir -p DEBFILE/usr/share/applications
desktop-file-validate drill-search.desktop
cp drill-search.desktop DEBFILE/usr/share/applications/

# add icon
mkdir -p DEBFILE/usr/share/icons/drill-search
#mkdir -p DEBFILE/usr/share/app-install/icons/

cp ../../assets/icon.png DEBFILE/usr/share/icons/drill-search/drill.png
#cp ../../assets/icon.svg DEBFILE/usr/share/app-install/icons/drill.svg


# build the .deb file
dpkg-deb --build DEBFILE
mv DEBFILE.deb Drill-GTK.deb
