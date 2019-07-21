module DrillGTK.Window;

////////////////////////////////
////////// SETTINGS ////////////
////////////////////////////////

// Window size always centered in the screen
const uint WINDOW_WIDTH = 960;
const uint WINDOW_HEIGHT = 540;

////////////////////////////////

import core.thread;

import std.stdio;
import std.algorithm;
import std.algorithm.iteration;
import std.concurrency;
import std.array : split, join;
import std.process : executeShell;
import std.container : Array;
import std.container.dlist : DList;
import std.algorithm : canFind;
import std.algorithm.mutation : copy;
import std.file : readText, DirEntry;
import std.concurrency : Tid;
import std.regex : Regex;
import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
import std.array;
import std.conv : to;

import gtk.ApplicationWindow : ApplicationWindow;
import gtk.ListStore;
import gtk.Entry;
import gtk.TreeView;
import gtk.Label;
import gtk.TreePath;
import gtk.TreeViewColumn;
import gtk.EditableIF;
import gtk.Application : Application;
import gtk.TreeIter;
import gtk.Box;
import gtk.ScrolledWindow;
import gtk.CellRendererPixbuf;
import gtk.CellRendererText;
import gdk.Threads;
import gdk.Event;
import gtk.Widget;

import glib.GException;


import FileInfo : FileInfo;
import Utils : sizeToHumanReadable;
import Logger : Logger;
import Utils : openFile;
import ApplicationInfo : ApplicationInfo, getApplications;


debug
{
    enum Column
    {
        TYPE,
        NAME_ICON,
        NAME,
        PATH,
        SIZE,
        DATE_MODIFIED,
        FOUND_BY_CRAWLER
    }
}
else
{
    enum Column
    {
        TYPE,
        NAME_ICON,
        NAME,
        PATH,
        SIZE,
        DATE_MODIFIED,
    }
}

void resultFound(immutable(FileInfo) result, void* userObject)
    {
         //Logger.logError(to!string(userObject),"RESULT CALLBACK 2");
        assert(userObject !is null);
        if (userObject is null)
            throw new Exception("window user object can't be null in resultFound");
        //assert(userObject !is null, );

        DrillWindow window = cast(DrillWindow)userObject;
            //Logger.logError(to!string(window),"RESULT CALLBACK 3");
        assert(window !is null);
        if (window is null)
            throw new Exception("userObject is not a DrillWindow GTK");
            
       // assert(window !is null, );

        window.list_dirty = true;
        auto bufferNotShared = cast(DList!FileInfo*)window.buffer;


     (*bufferNotShared).insertFront(result);

  
            //*(cast(DList!FileInfo)window.buffer).insertFront(result);
        
   
    }


    import API: loadData, activeCrawlersCount, stopCrawlingSync, stopCrawlingAsync, startCrawling;

extern (C) static nothrow int threadIdleProcess(void* data)
in(data != null, "data can't be null in GTK task")
out(r; r == 0 || r == 1, "GTK task should return 0 or 1")
{

    try
    {
        assert(data != null);
        DrillWindow mainWindow = cast(DrillWindow) data;
        const ulong crawlers_count = activeCrawlersCount(mainWindow.context);
        const icon_to_use = ["object-select", "emblem-synchronizing"];
        mainWindow.search_input.setIconFromIconName(GtkEntryIconPosition.PRIMARY,
                icon_to_use[crawlers_count != 0]);

        debug
        {

            mainWindow.threads_active.setText("Crawlers active: " ~ to!string(crawlers_count));

        }
        if (mainWindow.list_dirty)
        {

            // mainWindow.files_ignored_count.setText("Files ignored: " ~ to!string(ignored_total));
            assert(mainWindow.buffer != null);
            assert(mainWindow.buffer == &mainWindow.buffer1
                    || mainWindow.buffer == &mainWindow.buffer2);

            if (mainWindow.buffer == &mainWindow.buffer1)
                mainWindow.buffer = &mainWindow.buffer2;
            if (mainWindow.buffer == &mainWindow.buffer2)
                mainWindow.buffer = &mainWindow.buffer1;

            //mainWindow.buffer_mutex.lock_nothrow();

            DList!FileInfo thread_local_buffer = cast(DList!FileInfo)*mainWindow.buffer;
            foreach (FileInfo fi; thread_local_buffer)
                mainWindow.appendRecord(fi);
            // thread_local_buffer.clear();
            *mainWindow.buffer = DList!FileInfo();

            //mainWindow.buffer_mutex.unlock_nothrow();

            debug
            {
                assert(mainWindow.treeview !is null);
                mainWindow.files_indexed_count.setText("Files found: " ~ to!string(
                        mainWindow.liststore.iterNChildren(null)));
            }
            mainWindow.list_dirty = false;
        }
        gdk.Threads.threadsAddTimeout(100, &threadIdleProcess, data);
        if (!mainWindow.running)
        {
            return 0;
        }
    }
    catch (Throwable t)
    {
        return 0;
    }
    return 1;
}

class DrillWindow : ApplicationWindow
{
    /**
    Flag set to true when a crawler from the DrillAPI
    finds a new result, so GTK can add it to the GUI by using the GTK main thread
    */
    bool list_dirty;

private:

    // Hashmap to associate icons to extension
    string[string] iconmap;

    // The input box where the user writes the search
    Entry search_input;

    // The list where files appear
    ListStore liststore;
    TreeView treeview;

    shared(DList!FileInfo) buffer1;
    shared(DList!FileInfo) buffer2;
    shared(DList!FileInfo)* buffer;

    debug
    {
        Label threads_active;
        Label files_indexed_count;
        Label files_ignored_count;

    }
    else
    {
        Label github_notice;
    }

    bool running;

    private:

    void appendAllApplications()
    {
        ApplicationInfo[] applications = getApplications();
        foreach (ApplicationInfo app; applications)
        {
            import std.uni : toLower;
            appendApplication(cast(immutable(ApplicationInfo))app);
        }
    }

    import API : DrillData, DrillContext;
    
    DrillData data;
    DrillContext context;

public:

    public this(immutable(string) drillExecutableLocation, Application application)
    {
        super(application);

        buffer = &buffer1;

        immutable(string) assetsFolder = buildPath(absolutePath(dirName(buildNormalizedPath(drillExecutableLocation))), "Assets");
        data = loadData(assetsFolder);

        
        debug
        {
            this.setTitle("Drill (DEBUG VERSION)");
        }
        else
        {
            this.setTitle("Drill");
        }

        // MenuBar mb = new MenuBar();
        // Menu menu1 = new Menu();
        // MenuItem file = new MenuItem("_File");
        // file.setSubmenu(menu1);

        // mb.append(file);

        this.setSizeRequest(WINDOW_WIDTH, WINDOW_HEIGHT);
        this.setResizable(true);
        this.setPosition(GtkWindowPosition.CENTER);

        this.loadGTKIconFiletypes(assetsFolder);
        this.loadGTKIcon(assetsFolder);

        this.treeview = new TreeView();
        treeview.setEnableSearch(false);

        // tries to draw the rows with alternate colors
        // it will do nothing if the theme does not support it
        treeview.setRulesHint(true);
        
        this.createNewList();
        this.treeview.addOnRowActivated(&doubleclick);

        Box v = new Box(GtkOrientation.VERTICAL, 8);
        Box h = new Box(GtkOrientation.HORIZONTAL, 8);

        this.add(v);

        search_input = new Entry();
        search_input.setIconFromIconName(GtkEntryIconPosition.SECONDARY, null);

        ScrolledWindow scroll = new ScrolledWindow();
        //scroll.setMaxContentHeight(300);
        //scroll.setMinContentHeight(300);

        scroll.add(this.treeview);

        appendAllApplications();

        search_input.addOnChanged(&searchChanged);

        debug
        {
            this.files_indexed_count = new Label("Files indexed: ?");
            this.files_ignored_count = new Label("Files blocked: ?");
            this.threads_active = new Label("Crawlers active: ?");
           

            h.packStart(files_indexed_count, false, false, 0);
            h.packStart(files_ignored_count, false, false, 0);
            h.packStart(threads_active, false, false, 0);

        }
        else
        {
            import API : GITHUB_URL, AUTHOR_URL, AUTHOR_NAME, VERSION;
            this.github_notice = new Label("");
            this.github_notice.setSelectable(true);
            this.github_notice.setJustify(GtkJustification.CENTER);
            this.github_notice.setHalign(GtkAlign.CENTER);
            this.github_notice.setMarkup(
                "<a href=\""~GITHUB_URL~"\">Drill</a>"~
                " is maintained by "~
                "<a href=\""~AUTHOR_URL~"\">"~AUTHOR_NAME~"</a>"
                 ~ " " ~ VERSION
            );
            h.packStart(github_notice, true, true, 0);
        }


        // the Type column is used to determine what to do when
        // a user double clicks the row
        // and it's shown only on debug builds
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle("Type");
        column.setFixedWidth(80);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);
        debug
        {
            this.treeview.appendColumn(column);
        }
        const int CELL_HEIGHT = 32;
        CellRendererText cell_text = new CellRendererText();
        cell_text.setFixedSize(-1,CELL_HEIGHT);
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.TYPE);
        
        // file_icon.setIconName("file");

        // create second column with two renderers
         column = new TreeViewColumn();
        column.setTitle("Name");
        column.setFixedWidth(450);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        CellRendererPixbuf file_icon = new CellRendererPixbuf();
        file_icon.setProperty("icon-name", "dialog-question");
        file_icon.setProperty("stock-size", 5);
        file_icon.setFixedSize(-1,CELL_HEIGHT);

        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        cell_text.setFixedSize(-1,CELL_HEIGHT);
        column.packStart(file_icon, false);
        column.packStart(cell_text, true);
        column.addAttribute(cell_text, "text", Column.NAME);
        column.addAttribute(file_icon, "icon-name", Column.NAME_ICON);

        column = new TreeViewColumn();
        column.setTitle("Path");
        column.setFixedWidth(250);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        cell_text.setFixedSize(-1,CELL_HEIGHT);
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.PATH);

        // create first column with text renderer
        column = new TreeViewColumn();
        column.setTitle("Size");
        this.treeview.appendColumn(column);
        column.setFixedWidth(75);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        cell_text = new CellRendererText();
        cell_text.setFixedSize(-1,CELL_HEIGHT);
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.SIZE);

        column = new TreeViewColumn();
        column.setTitle("Date Modified");
        column.setFixedWidth(150);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        cell_text.setFixedSize(-1,CELL_HEIGHT);
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.DATE_MODIFIED);

        debug
        {
            column = new TreeViewColumn();
            column.setTitle("Found by crawler");
            column.setFixedWidth(200);
            column.setResizable(true);
            column.setSizing(GtkTreeViewColumnSizing.FIXED);

            this.treeview.appendColumn(column);
            cell_text = new CellRendererText();
            cell_text.setFixedSize(-1,CELL_HEIGHT);
            column.packStart(cell_text, false);
            column.addAttribute(cell_text, "text", Column.FOUND_BY_CRAWLER);
        }

        // v.packStart(mb, false, false, 0);
        v.packStart(search_input, false, false, 0);
        v.packStart(scroll, true, true, 0);
        v.packStart(h, false, true, 0);

        // Spawn all widgets
        this.showAll();

        gdk.Threads.threadsAddTimeout(10, &threadIdleProcess, cast(void*) this);

        addOnDelete(delegate bool(Event event, Widget widget) {
            Logger.logInfo("Window started to close, stopping crawlers");
            // this is the last chance to stop things before GTK really closes
            stopCrawlingSync(context);
            return false;
        });

        addOnKeyPress(delegate bool(GdkEventKey* event, Widget widget) {
            import gdk.Keysyms : GdkKeysyms;

            if (event.keyval == GdkKeysyms.GDK_Escape)
            {
                Logger.logInfo("ESC pressed, window is closing");
                this.close();
                return true;
            }
            return false;
        });

        // this is used so GTK will not complain about undocumented TreeView height
        treeview.setFixedHeightMode(true);
    }

private:

    void appendApplication(immutable(ApplicationInfo) applicationInfo)
    {
        TreeIter it = liststore.createIter();
        liststore.setValue(it, Column.TYPE, "Application");
        liststore.setValue(it, Column.NAME_ICON, applicationInfo.icon);
        liststore.setValue(it, Column.SIZE, "");
        liststore.setValue(it, Column.NAME, applicationInfo.name);
        liststore.setValue(it, Column.PATH, join(applicationInfo.execProcess, " "));
        liststore.setValue(it, Column.DATE_MODIFIED, applicationInfo.desktopFileDateModifiedString);
    }

    void appendRecord(immutable(FileInfo) fi)
    {

        TreeIter it = liststore.createIter();

        import std.conv : to;

        if (fi.isDirectory)
        {
            liststore.setValue(it, Column.TYPE, "Folder");
            liststore.setValue(it, Column.NAME_ICON, "folder");
            liststore.setValue(it, Column.SIZE, "");
        }
        else
        {
            liststore.setValue(it, Column.TYPE, "File");
            liststore.setValue(it, Column.NAME_ICON, "text-x-generic");
            liststore.setValue(it, Column.SIZE, fi.sizeString);
            auto ext = fi.extension;
            if (ext != null)
            {
                const string* p = (ext in this.iconmap);
                if (p !is null)
                {
                    auto icon_name = this.iconmap[ext];
                    assert(icon_name != null);
                    liststore.setValue(it, Column.NAME_ICON, icon_name);

                    Logger.logTrace(fi.extension ~ " setting icon to " ~ this.iconmap[ext]);
                }
            }

        }

        // import gtk.Requisition;
        // Requisition requisition;
        // this.sizeRequest(requisition);

        liststore.setValue(it, Column.NAME, fi.fileName);
        liststore.setValue(it, Column.PATH, fi.containingFolder);
        liststore.setValue(it, Column.DATE_MODIFIED, fi.dateModifiedString);
        debug
        {
            liststore.setValue(it, Column.FOUND_BY_CRAWLER, fi.originalMountpoint);
        }

        Logger.logTrace("[DRILL][GTK] Added to the list: " ~ fi.fullPath);
        // this.setSizeRequest(requisition.width,requisition.height);
    }

     import std.path : chainPath;
        import std.array : array;

    private void doubleclick(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter();
        this.liststore.getIter(ti, tp);
        immutable(string) path = this.liststore.getValueString(ti, Column.PATH);
        immutable(string) name = this.liststore.getValueString(ti, Column.NAME);
        immutable(string) type = this.liststore.getValueString(ti, Column.TYPE);

        import gtk.MessageDialog;

        if (type == "Application")
        {
            import std.process : spawnProcess;
            import std.stdio : stdin, stdout, stderr;
            import std.process : Config;
            import Utils : cleanExecLine;

            try
            {
                spawnProcess(cleanExecLine(path), null, Config.none, null);
            }
            catch (Exception e)
            {
                MessageDialog d = new MessageDialog(this, GtkDialogFlags.MODAL, MessageType.ERROR,
                        ButtonsType.OK, "Error starting application `" ~ path ~ "`\n" ~ e.msg);
                d.run();
                d.destroy();
            }
        }
        else
        {
            string chained = chainPath(path, name).array;
            try
            {

                openFile(chained);
            }
            catch (Exception e)
            {
                MessageDialog d = new MessageDialog(this, GtkDialogFlags.MODAL, MessageType.ERROR,
                        ButtonsType.OK, "Error opening file `" ~ chained ~ "`\n" ~ e.msg);
                d.run();
                d.destroy();
            }
        }
    }

    

    private void createNewList()
    {
        debug
        {
            this.liststore = new ListStore([
                    GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.STRING,
                    GType.STRING, GType.STRING
                    ]);
        }
        else
        {
            this.liststore = new ListStore([
                    GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.STRING,
                    GType.STRING
                    ]);
        }

        this.treeview.setModel(this.liststore);

    }

    private void searchChanged(EditableIF ei)
    {

        stopCrawlingAsync(context);

        buffer1 = DList!FileInfo();
        buffer2 = DList!FileInfo();
        buffer = &buffer1;

        // this is realistically faster than liststore.clear();
        // assigning a new list is O(1)
        // instead clearing the list in GTK uses a foreach
        createNewList();

        immutable(string) search_string = ei.getChars(0, -1);
        Logger.logTrace("Wrote input:" ~ search_string);

        if (search_string.length != 0)
        {
            
            ApplicationInfo[] applications = getApplications();
            foreach (ApplicationInfo application; applications)
            {
                import std.uni : toLower;
                if (canFind(application.name.toLower(), search_string.toLower()))
                {     
                    appendApplication(cast(immutable(ApplicationInfo))application);
                }
            }
            
            //debug drillapi.setSinglethread(true);
            auto callback = (&resultFound);
            context = startCrawling(data,search_string,callback,cast(void*)this);
        }
        else
        {
            appendAllApplications();
        }
    }

    private void loadGTKIconFiletypes(immutable(string) assetsFolder)
    {
        import std.file : dirEntries, SpanMode;
        import std.path : buildNormalizedPath, absolutePath;
        import std.path : buildPath;

        try
        {
            auto filetypes_file = dirEntries(DirEntry(buildPath(assetsFolder,
                    "IconsAssociations")), SpanMode.shallow, true);

            foreach (string partial_filetype; filetypes_file)
            {
                string[] extensions = readText(partial_filetype).split("\n");
                foreach (ext; extensions)
                {
                    static import std.path;
                    import std.path : stripExtension;

                    iconmap[ext] = std.path.baseName(stripExtension(partial_filetype));
                }
            }
        }
        catch (std.file.FileException e)
        {
            Logger.logError("Error reading icons associations, not using icons" ~ e.toString());
        }

    }

    public void loadGTKIcon(immutable(string) assetsFolder)
    {
        import std.path : buildPath;

        try
        {
            this.setIconFromFile(buildPath(assetsFolder, "icon.png"));
        }
        catch (GException ge)
        {
            Logger.logError(
                    "Can't find program icon, will fallback to default GTK one! " ~ ge.toString());

            //fallback to default GTK icon if it can't find its own
            this.setIconName("search");
        }

    }

}
