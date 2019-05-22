
wget http://downloads.dlang.org/nightlies/dmd-master/dmd.master.windows.7z;
7z x dmd.master.windows.7z;
git clone https://github.com/yatima1460/GTK3-windows-32bit;
cd source/cli
../../dmd2/windows/bin/dub build -b release --parallel --force --arch=x86
cd ../../
7z a -tzip ../../build/Drill-cli-windows-$TRAVIS_TAG-x86.zip assets drill-cli.exe;
cd source/gtkui
../../dmd2/windows/bin/dub build -b release --parallel --force --arch=x86;
cd ../../
mv GTK3-windows-32bit/*.dll .;
7z a -tzip ../../build/Drill-gtk-windows-$TRAVIS_TAG-x86.zip assets drill-gtk.exe DRILL_VERSION *.dll;
