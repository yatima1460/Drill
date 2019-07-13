module WebView;

import core.stdc.stdio :printf;

import std.array : join;
import std.stdio : writeln, readln;
import std.path : buildPath;
import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;

import API : DrillAPI;
import DhanosInterface : DhanosInterface;
import Dhanos : getNewPlatformInstance;



 void exit(DhanosInterface* d, immutable(string) value)
    {
        writeln("[Drill] drill_exit js callback");
     
        // writeln("DHANOS_PTR");
         writeln(d);

         auto dd = *d;
          writeln(dd);

         dd.close();   
        // writeln("drill_exit end"); 
    }


int main(string[] args)
{
    writeln("Drill WebView v"~DrillAPI.DRILL_VERSION~" - "~DrillAPI.GITHUB_URL);
    immutable(string) title = "Drill";
        immutable(string) dhanos_project_path = dirName(absolutePath(buildNormalizedPath(args[0])));
        immutable(string) url = buildPath("file:" ~ dhanos_project_path ~ "/drill.html");
        immutable int width = 800;
        immutable int height = 250;
        immutable bool resizable = false;
         DhanosInterface d = getNewPlatformInstance(title, url, width, height, resizable);
    
        d.setCallback("exit",&exit);
        //d.setBorder(false);
        d.mainLoop();
    return 0;
}
