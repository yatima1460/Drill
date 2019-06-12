#!/bin/bash
 



if [ -z "$TRAVIS_TAG" ]; then
  echo No Drill version found! Using LOCAL_BUILD
  export TRAVIS_TAG="LOCAL_BUILD"
fi

mkdir Build
FILES="../../Source/Frontend/GTK/Build/*
../../Source/Frontend/CLI/Build/*
../../Source/Frontend/WinAPI/Build/*
"



for f in $FILES
do
  echo "Processing $f file..."

  if [[ -d "$f" ]]; then
    echo "$f exists"
    7z a -tzip $f-$TRAVIS_TAG.zip $f
    mv $f-$TRAVIS_TAG.zip Build
  else
    echo "$f does not exist, skipping"
  fi
  
done