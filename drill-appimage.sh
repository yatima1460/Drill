
rm -rf Drill-x86_64.AppImage
#rmdir Drill-x86_64.AppImage
mkdir -p Drill-x86_64.AppImage/drill.AppDir
cp drill.png Drill-x86_64.AppImage/drill.AppDir
cd Drill-x86_64.AppImage/
wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh

cd drill.AppDir
HERE=$(dirname $(readlink -f "${0}"))

bash ../Miniconda3-latest-Linux-x86_64.sh -b -p ./conda
rm ../Miniconda3-latest-Linux-x86_64.sh
PATH="${HERE}"/conda/bin:$PATH
#conda config --add channels conda-forge
#conda config --add channels drill
#conda create -n drill drill python=3.5 -y

cd ..


cp ${HERE}/drill.png .

cat > ./AppRun <<\EOF
#!/bin/sh
HERE=$(dirname $(readlink -f "${0}"))
export PATH="${HERE}"/miniconda3/bin:$PATH
source activate drill
drill
EOF

chmod a+x ./AppRun


cat > ./Drill.desktop <<\EOF
[Desktop Entry]
Name=Drill
Icon=drill.png
Exec=Drill %u
Categories=Search;
StartupNotify=true
EOF