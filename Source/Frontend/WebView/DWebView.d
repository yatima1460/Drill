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


void drill_return(DhanosInterface d, immutable(string) value)
{

    writeln("return pressed");
}

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



void open_drill_website(DhanosInterface d, immutable(string) value)
{
    writeln("open_drill_website");
    import Utils : openFile;
    openFile(DrillAPI.WEBSITE_URL);
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
    immutable int width = 960;
    immutable int height = 80;
    // width = 100;
    // height = 100;
    immutable bool resizable = false;

    DhanosInterface d = getNewPlatformInstance(title, url, width, height, resizable);

    immutable(string) assetsFolder = buildPath(absolutePath(dirName(buildNormalizedPath(args[0]))), "Assets");
    DrillAPI drillapi = new DrillAPI(assetsFolder);

d.setBorder(false);
    d.setAlwaysOnTop(true);
   
    d.setCallback("loaded",&dhanos_page_loaded);
    d.setCallback("close", &drill_exit);
    d.setCallback("search", &search);
    d.setCallback("return", &drill_return);
    d.setCallback("open_drill_website", &open_drill_website);
    
    d.mainLoop();
    return 0;
}
