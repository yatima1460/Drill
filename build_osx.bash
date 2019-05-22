#!/bin/bash

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

build() {
    info "Starting build of $1..."
    cd $1 $OUTPUT
    dub build -b release --parallel --arch=x86_64 $OUTPUT
    if [ $? -eq 0 ]; then
        info "$1 built correctly"
    else
        error "Building $1... failed"
        exit 1
    fi
    cd - $OUTPUT
}

info "OSX build started"
cd source/cli
dub build -b release --parallel --force --arch=x86_64;
cd ../../
7z a -tzip ../../build/Drill-cli-osx-$TRAVIS_TAG-x86_64.zip assets drill-cli DRILL_VERSION;
cd source/gtkui
dub build -b release --parallel --force --arch=x86_64;
7z a -tzip ../../build/Drill-gtk-osx-$TRAVIS_TAG-x86_64.zip assets drill-gtk DRILL_VERSION;
cd ../../
