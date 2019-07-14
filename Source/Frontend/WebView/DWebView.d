module WebView;

import core.stdc.stdio : printf;

import std.array : join;
import std.stdio : writeln, readln;
import std.path : buildPath;
import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;

import API : DrillAPI;
import FileInfo : FileInfo;

import DhanosInterface : DhanosInterface;
import Dhanos : getNewPlatformInstance;

extern (C) int gdk_screen_width();
extern (C) int gdk_screen_height();



/**
    JS Callback: Closes Drill when the user presses ESC or Return when no input
*/
void drill_exit(DhanosInterface d, immutable(string) value)
{
    writeln("[Drill] drill_exit js callback");
    d.close();
}

/**
    DrillAPI callback called when Drill finds a new result
*/
void resultFound(immutable(FileInfo) result)
{
     writeln("[Drill] resultFound START");
    synchronized
    {
            writeln(result.fileName);
    }
    

     writeln("[Drill] resultFound END");
    //list_dirty = true;
    //(cast(DList!FileInfo)*buffer).insertFront(result);
}

/**
    JS Callback: called when the user inputs something
*/
extern (D) void search(DhanosInterface d, immutable(string) value)
{
    assert(value !is null);
    writeln("[Drill] search");

    // writeln("DHANOS_PTR");
    writeln(value);

    if (value == "")
    {
        writeln("[Drill] return to normal size");
        d.setWindowSize(gdk_screen_width()/2,78);
       
    }
    else
    {
        writeln("[Drill] set bigger window size");
        d.setWindowSize(gdk_screen_width()/2,200);
    }

    auto drillapi = cast(DrillAPI)d.getUserObject();

    assert(drillapi !is null);

    writeln("[Drill] crawling stop");
    drillapi.stopCrawlingAsync();
        

    import std.functional : toDelegate;
    drillapi.startCrawling("%£da", toDelegate(&resultFound));


    writeln("[Drill] search END");

   
    //d.close();   
    // writeln("drill_exit end"); 
}

import ApplicationInfo : ApplicationInfo;


/**
    JS Callback: called when the user presses Return and the input is not empty
*/
void drill_return(DhanosInterface d, immutable(string) value)
{

    writeln("return pressed");
}


// /**
//     JS Callback: called when the page loaded
// */
// void dhanos_page_loaded(DhanosInterface d, immutable(string) value)
// {

//     ApplicationInfo[] applications = DrillAPI.getApplicationsInfo();

//     int i = 0;
//     foreach (ApplicationInfo app; applications)
//     {
//         if (i == 10)
//             break;
//         import std.uni : toLower;

//         d.runJavascript("addApplication(
//             \"" ~ app.icon ~ "\",
//             \"" ~ app.name ~ "\",
//             \""
//                 ~ app.exec ~ "\",
//             \"" ~ app.desktopFileDateModifiedString ~ "\"
//             )");
//         i++;
//         //appendApplication(d,cast(immutable(ApplicationInfo))app);
//     }
// }

/**
    JS Callback: Opens the Drill website when the user clicks on the logo
*/
void open_drill_website(DhanosInterface d, immutable(string) value)
{
    writeln("open_drill_website");
    import Utils : openFile;

    openFile(DrillAPI.WEBSITE_URL);
}


int main(string[] args)
{
    writeln("Drill WebView v" ~ DrillAPI.DRILL_VERSION ~ " - " ~ DrillAPI.GITHUB_URL);
    immutable(string) title = "Drill";
    immutable(string) dhanos_project_path = dirName(absolutePath(buildNormalizedPath(args[0])));
    immutable(string) url = buildPath("file:" ~ dhanos_project_path ~ "/drill.html");
    immutable int width = 960;
    immutable int height = 78;
    // width = 100;
    // height = 100;
    immutable bool resizable = false;

    DhanosInterface d = getNewPlatformInstance(title, url, width, height, resizable);

    //d.setWindowSize(gdk_screen_width() / 2, cast(int)(gdk_screen_height() * 0.1f));

    immutable(string) assetsFolder = buildPath(
            absolutePath(dirName(buildNormalizedPath(args[0]))), "Assets");
    DrillAPI drillapi = new DrillAPI(assetsFolder);

    d.setBorder(false);
    d.setAlwaysOnTop(true);
    d.setUserObject(drillapi);

    //d.setCallback("loaded", &dhanos_page_loaded);
    d.setCallback("close", &drill_exit);
    d.setCallback("search", &search);
    d.setCallback("return", &drill_return);
    d.setCallback("open_drill_website", &open_drill_website);

    d.mainLoop();
    return 0;
}
