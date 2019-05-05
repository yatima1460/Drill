#!/bin/bash
cd ../usr/share/pyshared
echo $PWD
echo $PYTHONPATH
echo $PYTHONHOME
ls
export PATH="$PATH:$PWD"
python3 -O -OO -I -E drill.py