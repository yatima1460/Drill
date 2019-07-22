#!/bin/bash
 
DRILL_VERSION=$(cat ../../DRILL_VERSION)

mkdir Build
FILES="../../Source/Frontend/*/Build/*
"

for f in $FILES
do
  echo "Processing $f file..."

  if [[ -d "$f" ]]; then
    echo "$f exists"
    7z a -tzip "$f"-"$DRILL_VERSION".zip "$f"/*
    mv "$f"-$DRILL_VERSION.zip Build
  else
    echo "$f does not exist, skipping"
  fi
  
done

