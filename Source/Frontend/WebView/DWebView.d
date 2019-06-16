module WebView;

import std.array : join;
import std.stdio : writeln, readln;

import core.stdc.stdio :printf;

// import FileInfo : FileInfo;
// import API : DrillAPI;
// import Crawler : Crawler;
import std.path : buildPath;



extern (C) int webview(const char *title, const char *url, int width, int height, int resizable);




int main(string[] args)
{
//    writeln("Drill WebView v"~DrillAPI.DRILL_VERSION~" - "~DrillAPI.GITHUB_URL);
   //webview("Minimal webview example","https://en.m.wikipedia.org/wiki/Main_Page", 800, 600, 1);
     printf("%d",webview("Minimal webview example","https://en.m.wikipedia.org/wiki/Main_Page", 800, 600, 1));

       
    return 0;
}
