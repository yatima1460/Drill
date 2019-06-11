#!/bin/bash
 

mkdir Build
FILES="../../Source/Frontend/GTK/Build/*
../../Source/Frontend/CLI/Build/*
../../Source/Frontend/WinAPI/Build/*
../../Source/Frontend/WinAPI/Build/*
../../Source/Backend/Build/*
"
for f in $FILES
do
  echo "Processing $f file..."
  7z a -tzip $f.zip $f
  
  mv $f.zip Build
  
done