#!/bin/bash
sudo apt install webkit2gtk-4.0
rm webview.o
gcc -c webview.c -DWEBVIEW_GTK=1 -DWEBVIEW_IMPLEMENTATION `pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.0` 
dmd  WebView.d webview.o
# -I/usr/include/glib-2.0 -I/usr/include/glib-2.0 -I/usr/include/webkit2gtk-4.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include -L-Lglib-2.0 -L-Lgtk+-3.0 -L-Llibwebkit2gtk-4.0-37
#  -L-Lgtk-3.0