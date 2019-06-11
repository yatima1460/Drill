#!/bin/bash
 

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
    7z a -tzip $f.zip $f
    mv $f.zip Build
  else
    echo "$f does not exist, skipping"
  fi
  
done