#!/bin/bash

if [ -f ../../Drill-GTK ]; then
    echo Drill-GTK executable found
else
    echo No Drill-GTK executable found!
    exit 1
fi

rm -rf RPMFILE

mkdir -p RPMFILE/SOURCES RPMFILE/SPECS

cd RPMFILE/SOURCES