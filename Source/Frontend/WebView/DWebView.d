module WebView;

import std.array : join;
import std.stdio : writeln, readln;

import core.stdc.stdio :printf;

// import FileInfo : FileInfo;
 import API : DrillAPI;
// import Crawler : Crawler;
import std.path : buildPath;





import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;

import DhanosInterface : DhanosInterface;
import Dhanos : getNewPlatformInstance;

void callback(immutable(string) value)
{
    writeln("borderless js callback");
    writeln("value "~value);
    
}




int main(string[] args)
{
    writeln("Drill WebView v"~DrillAPI.DRILL_VERSION~" - "~DrillAPI.GITHUB_URL);
   //webview("Minimal webview example","https://en.m.wikipedia.org/wiki/Main_Page", 800, 600, 1);
     //printf("%d",webview("Minimal webview example","file://drill.html", 800, 600, 1));
 immutable(string) title = "Drill";
    immutable(string) dhanos_project_path = dirName(absolutePath(buildNormalizedPath(args[0])));
    immutable(string) url = buildPath("file:" ~ dhanos_project_path ~ "/drill.html");
    immutable int width = 800;
    immutable int height = 250;
    immutable bool resizable = false;
    DhanosInterface d = getNewPlatformInstance(title, url, width, height, resizable);
    
    //md.setBorder(false);
    auto f = &callback;
    d.setJSCallback(f);
    d.mainLoop();
    
       
    return 0;
}
