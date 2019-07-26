module WebView;

import core.stdc.stdio : printf;

// import std.array : join;
// import std.stdio : writeln, readln;
// import std.path : buildPath;
// import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
// import Dhanos : getNewPlatformInstance;

import FileInfo : FileInfo;
import DhanosInterface : DhanosInterface;

@safe @nogc nothrow pure extern (C) int gdk_screen_width();
@safe @nogc nothrow pure extern (C) int gdk_screen_height();

/**
    JS Callback: Opens the Drill website when the user clicks on the logo
*/
nothrow void jsOpenDrillWebsite(ref DhanosInterface dhanosInterface, immutable(string) value)
in(dhanosInterface !is null)
in(value !is null)
{
    import Utils : openFile;
    import Meta : WEBSITE_URL;

    openFile(WEBSITE_URL);
    dhanosInterface.close();
}

/**
    JS Callback: Closes Drill when the user presses ESC or Return when no input
*/
void jsExit(ref DhanosInterface dhanosInterface, immutable(string) value)
in(dhanosInterface !is null)
in(value !is null)
{
    import Context : DrillContext; 

    // if at least one search has been made
    if (dhanosInterface.getUserObject().peek!(DrillContext*) !is null)
    {
        import Context : stopCrawlingSync;
        DrillContext* context = dhanosInterface.getUserObject().get!(DrillContext*);
        (*context).stopCrawlingSync();
    }
    dhanosInterface.close();
}

/**
    Drill callback called when Drill finds a new result
*/
void resultFound(immutable(FileInfo) result, Variant userObject)
in(result.fileName !is null)
in(result.fileName.length > 0)
in(result.fullPath !is null)
in(result.fullPath.length > 0)
in(result.dateModifiedString !is null)
in(result.dateModifiedString.length > 0)
{
    synchronized
    {
        DhanosInterface d = ((cast(Variant)userObject).get!(DhanosInterface));

        import std.string : format;

        auto jsCommand = format("addApplication('%s','%s','%s','%s');", "icon",
                result.fileName, result.fullPath, result.dateModifiedString);

        import std.stdio : writeln;

        writeln(jsCommand);
        (cast(DhanosInterface*) d).runJavascript(jsCommand);
    }

    // import std.stdio : writeln;
    // synchronized
    // {
    //     writeln(result.fileName);
    // }
    //list_dirty = true;
    //(cast(DList!FileInfo)*buffer).insertFront(result);
}

/**
    JS Callback: called when the user inputs something
*/
void jsSearch(ref DhanosInterface dhanosInterface, immutable(string) value)
in(dhanosInterface !is null)
in(value !is null)
{

    import std.stdio : writeln;

    if (value == "")
    {
        dhanosInterface.setWindowSize(gdk_screen_width() / 2, 78);
    }
    else
    {
        dhanosInterface.setWindowSize(gdk_screen_width() / 2, 200);
    }

    import Context : DrillContext;

    // if old Drill search exists stop it
    if (dhanosInterface.getUserObject().peek!(DrillContext*))
    {
        DrillContext* context = dhanosInterface.getUserObject().get!(DrillContext*);
        assert(context !is null);
        //writeln("[Drill] crawling stop");
        import Context : stopCrawlingSync;

        (*context).stopCrawlingSync();
    }

    // start a new Drill search
    import Context : startCrawling;
    import Config : loadData;
    import std.file : thisExePath;
    import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;

    auto assetsPath = buildPath(dirName(thisExePath()), "Assets");
    auto config = loadData(assetsPath);
    import Config : DrillConfig;

    auto v = Variant(dhanosInterface);
    DrillContext* context = startCrawling(config, value, &resultFound,v);
    dhanosInterface.setUserObject(Variant(context));

    // writeln("[Drill] search END");

    //import core.memory;
    //GC.collect();
}

import ApplicationInfo : ApplicationInfo;

/**
    JS Callback: called when the user presses Return and the input is not empty
*/
void jsReturnPressed(ref DhanosInterface dhanosInterface, immutable(string) value)
in(dhanosInterface !is null)
in(value !is null)
{
    import std.stdio : writeln;

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

void dhanosLoadFinished(DhanosInterface d)
{
    import std.stdio:writeln;
    writeln("dhanosLoadFinished");
    d.setBorder(false);
    d.setAlwaysOnTop(true);

    d.setCallback("close", &jsExit);
    d.setCallback("search", &jsSearch);
    d.setCallback("return", &jsReturnPressed);
    d.setCallback("open_drill_website", &jsOpenDrillWebsite);
}

import std.variant : Variant;

int main(string[] args)
{
    import core.memory;

    //GC.disable();
    import std.stdio : writeln;
    import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
    import Meta : VERSION, GITHUB_URL;

    writeln("Drill WebView v" ~ VERSION ~ " - " ~ GITHUB_URL);
    immutable(string) title = "Drill";
    immutable(string) dhanos_project_path = dirName(absolutePath(buildNormalizedPath(args[0])));
    immutable(string) url = buildPath("file:" ~ dhanos_project_path ~ "/drill.html");
    immutable int width = 960;
    immutable int height = 78;
    // width = 100;
    // height = 100;
    immutable bool resizable = false;

    import std.variant : Variant;


    // Variant o;
    // int* t = new int();
    // *t = 42;
    // o = cast(Variant)t;
    // writeln(t);
    // writeln(*t);
    // writeln(o.get!(int*));

    

    import Dhanos : getNewPlatformInstance;

    DhanosInterface d = getNewPlatformInstance(title, url, width, height, resizable, &dhanosLoadFinished);
    assert(d !is null);

    //d.setWindowSize(gdk_screen_width() / 2, cast(int)(gdk_screen_height() * 0.1f));

    immutable(string) assetsFolder = buildPath(
            absolutePath(dirName(buildNormalizedPath(args[0]))), "Assets");

  

    
    //d.setUserObject(drillapi);



    //d.setCallback("loaded", &dhanos_page_loaded);


    d.mainLoop();
    return 0;
}
