module WebView;

import core.stdc.stdio : printf;

import std.array : join;
import std.stdio : writeln, readln;
import std.path : buildPath;
import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;

import API : DrillAPI;
import DhanosInterface : DhanosInterface;
import Dhanos : getNewPlatformInstance;

void drill_exit(DhanosInterface d, immutable(string) value)
{
    writeln("[Drill] drill_exit js callback");

    // writeln("DHANOS_PTR");
    writeln(d);

    d.close();
    // writeln("drill_exit end"); 
}

void search(DhanosInterface d, immutable(string) value)
{
    writeln("[Drill] search");

    // writeln("DHANOS_PTR");
    writeln(value);

    //d.close();   
    // writeln("drill_exit end"); 
}

import ApplicationInfo : ApplicationInfo;

void dhanos_page_loaded(DhanosInterface d, immutable(string) value)
{

    
    ApplicationInfo[] applications = DrillAPI.getApplicationsInfo();

    int i = 0;
    foreach (ApplicationInfo app; applications)
    {
        if (i == 10) break;
        import std.uni : toLower;
        d.runJavascript("addApplication(
            \""~app.icon~"\",
            \""~app.name~"\",
            \""~app.exec~"\",
            \""~app.desktopFileDateModifiedString~"\"
            )");
        i++;
        //appendApplication(d,cast(immutable(ApplicationInfo))app);
    }
}

void appendApplication(DhanosInterface d, immutable(ApplicationInfo) a)
{
    d.runJavascript("javascript:addApplication("~a.name~");");
}

int main(string[] args)
{
    writeln("Drill WebView v" ~ DrillAPI.DRILL_VERSION ~ " - " ~ DrillAPI.GITHUB_URL);
    immutable(string) title = "Drill";
    immutable(string) dhanos_project_path = dirName(absolutePath(buildNormalizedPath(args[0])));
    immutable(string) url = buildPath("file:" ~ dhanos_project_path ~ "/drill.html");
    immutable int width = 800;
    immutable int height = 450;
    immutable bool resizable = false;

    DhanosInterface d = getNewPlatformInstance(title, url, width, height, resizable);

    immutable(string) assetsFolder = buildPath(absolutePath(dirName(buildNormalizedPath(args[0]))), "Assets");
    DrillAPI drillapi = new DrillAPI(assetsFolder);

   
    d.setCallback("loaded",&dhanos_page_loaded);
    d.setCallback("exit", &drill_exit);
    d.setCallback("search", &search);
    d.setBorder(false);
    d.mainLoop();
    return 0;
}
