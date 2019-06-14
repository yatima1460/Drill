module DrillGTK.Window;

////////////////////////////////
////////// SETTINGS ////////////
////////////////////////////////

// Window size always centered in the screen
const uint WINDOW_WIDTH = 960;
const uint WINDOW_HEIGHT = 540;

// Maximum number of files to show
// -1 for infinite, be careful it could slow down the UI
const uint UI_LIST_MAX_SIZE = 1000;

////////////////////////////////

import std.stdio;
import std.algorithm;
import std.algorithm.iteration;
import core.thread;
import std.concurrency;

import std.array : split, join;
import std.process : executeShell;
import std.container : Array;
import std.algorithm : canFind;
import std.algorithm.mutation : copy;
import std.file : readText;
import std.file : DirEntry;
import std.concurrency : Tid;
import std.regex : Regex;
import std.path;

import std.container.dlist : DList;


debug
{
    import std.experimental.logger : FileLogger;
}

import gdk.RGBA;
import gdk.Color;
import gdk.Threads;
import gdk.Pixbuf;

import gtk.Main;
import gdk.Event;
import gtk.Window;
import gtk.Widget;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.Entry;
import gtk.Box;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.CellRendererPixbuf;
import gtk.CellRendererToggle;
import gtk.ListStore;
import gtk.EditableIF;
import gtk.ApplicationWindow : ApplicationWindow;
import gtk.Label;
import gtk.Scrollbar;
import gtk.ScrolledWindow;
import gtk.Menu;
import gtk.MenuBar;
import gtk.MenuItem;
import gtk.Application : Application;

import glib.GException;

import pango.PgFontDescription;

import gio.Application : GioApplication = Application;

// import drillcore.crawler : Crawler;
// import drillcore.utils : logConsole;
// import drill.core.api : DrillAPI;
import API : DrillAPI;
import FileInfo : FileInfo;
import Utils : humanSize;
import Logger : Logger;
import Utils : openFile;
import std.path : dirName, buildNormalizedPath, absolutePath, buildPath;
import std.array;
import std.conv : to;

debug {
    enum Column
    {
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
        NAME_ICON,
        NAME,
        PATH,
        SIZE,
        DATE_MODIFIED,
    }
}

extern (C) static nothrow int threadIdleProcess(void* data)
in(data != null, "data can't be null in GTK task")
out(r; r == 0 || r == 1, "GTK task should return 0 or 1")
{
    
    try
    {
        assert(data != null);
        DrillWindow mainWindow = cast(DrillWindow) data;
        const ulong crawlers_count = mainWindow.drillapi.getActiveCrawlersCount();
        const icon_to_use = ["object-select", "emblem-synchronizing"];
        mainWindow.search_input.setIconFromIconName(GtkEntryIconPosition.PRIMARY, icon_to_use[crawlers_count != 0]);

        debug
        {
           

            mainWindow.threads_active.setText("Crawlers active: " ~ to!string(crawlers_count));

        }
        if (mainWindow.list_dirty)
        {

            // mainWindow.files_ignored_count.setText("Files ignored: " ~ to!string(ignored_total));
            assert(mainWindow.buffer != null);
            assert(mainWindow.buffer == &mainWindow.buffer1 || mainWindow.buffer == &mainWindow.buffer2);

            if (mainWindow.buffer == &mainWindow.buffer1)
                mainWindow.buffer = &mainWindow.buffer2;
            if (mainWindow.buffer == &mainWindow.buffer2)
                mainWindow.buffer = &mainWindow.buffer1;

            //mainWindow.buffer_mutex.lock_nothrow();
            
            DList!FileInfo thread_local_buffer = cast(DList!FileInfo) *mainWindow.buffer;
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

import std.process;

class DrillWindow : ApplicationWindow
{

    /**
    Flag set to true when a crawler from the DrillAPI
    finds a new result, so GTK can add it to the GUI by using the GTK main thread
    */
    bool list_dirty;

private:
    DrillAPI drillapi;

    string[string] iconmap;
    ListStore liststore;

    Entry search_input;
    TreeView treeview;
 
    
    shared(DList!FileInfo) buffer1;
    shared(DList!FileInfo) buffer2;
    shared(DList!FileInfo)* buffer;

    import core.sync.mutex : Mutex;
    shared(Mutex) buffer_mutex;

    debug
    {
        Label threads_active;
        Label files_indexed_count;
        Label files_ignored_count;
        Label files_shown;
    }
    else
    {
        Label github_notice;
    }

    bool running;
    private Tid childTid;

    void appendRecord(immutable(FileInfo) fi)
    {
       
        
        TreeIter it = liststore.createIter();
     
        import std.conv : to;

        
        if (fi.isDirectory)
        {
            liststore.setValue(it, Column.NAME_ICON, "folder");
            liststore.setValue(it, Column.SIZE, "");
        }
        else
        {
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

                    Logger.logTrace(fi.extension~" setting icon to " ~ this.iconmap[ext]);
                }
            }

        }

        // import gtk.Requisition;
        // Requisition requisition;
        // this.sizeRequest(requisition);

        liststore.setValue(it, Column.NAME, fi.fileName);
        liststore.setValue(it, Column.PATH, fi.containingFolder);
        liststore.setValue(it, Column.DATE_MODIFIED, fi.dateModifiedString);
        debug{liststore.setValue(it, Column.FOUND_BY_CRAWLER, fi.originalMountpoint);}

        Logger.logTrace("[DRILL][GTK] Added to the list: "~fi.fullPath);
        // this.setSizeRequest(requisition.width,requisition.height);
    }

    private void doubleclick(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter();
        this.liststore.getIter(ti, tp);
        string path = this.liststore.getValueString(ti, Column.PATH);
        string name = this.liststore.getValueString(ti, Column.NAME);
        import std.path : chainPath;
        import std.array : array;

        string chained = chainPath(path, name).array;

        openFile(chained);
        // TODO: open_file failed
    }

    

    private void resultFound(immutable(FileInfo) result)
    {
        list_dirty = true;
        (cast(DList!FileInfo)*buffer).insertFront(result);
    }


    private void createNewList()
    {
        debug {
            this.liststore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.STRING]);
        }
        else
        {
            this.liststore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.STRING]);
        }
       

       this.treeview.setModel(this.liststore);
       
    }

    private void searchChanged(EditableIF ei)
    {

        drillapi.stopCrawlingAsync();
        
     
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
            drillapi.startCrawling(search_string, &this.resultFound);
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
            Logger.logError("Can't find program icon, will fallback to default GTK one! " ~ ge.toString());

            //fallback to default GTK icon if it can't find its own
            this.setIconName("search");
        }

    }

    public this(immutable(string) exe_path, Application application)
    {

        buffer = &buffer1;

        import std.path : dirName, buildNormalizedPath;
        buffer_mutex = new shared Mutex();

        immutable(string) assetsFolder = buildPath(absolutePath(dirName(buildNormalizedPath(exe_path))),"Assets");
        drillapi = new DrillAPI(assetsFolder);

        super(application);
        this.setTitle("Drill");
        debug
        {
            this.setTitle("Drill (DEBUG VERSION)");
        }

        // MenuBar mb = new MenuBar();
        // Menu menu1 = new Menu();
        // MenuItem file = new MenuItem("_File");
        // file.setSubmenu(menu1);

        // mb.append(file);



        this.setSizeRequest(WINDOW_WIDTH,WINDOW_HEIGHT);
        this.setResizable(true);
        this.setPosition(GtkWindowPosition.CENTER);

        this.loadGTKIconFiletypes(assetsFolder);
        this.loadGTKIcon(assetsFolder);



        
        this.treeview = new TreeView();
        this.createNewList();
        this.treeview.addOnRowActivated(&doubleclick);

        Box v = new Box(GtkOrientation.VERTICAL, 8);
        Box h = new Box(GtkOrientation.HORIZONTAL, 8);

        add(v);

        search_input = new Entry();
        search_input.setIconFromIconName(GtkEntryIconPosition.SECONDARY, null);

        ScrolledWindow scroll = new ScrolledWindow();

        scroll.add(this.treeview);

        search_input.addOnChanged(&searchChanged);

        debug
        {
            this.files_indexed_count = new Label("Files indexed: ?");
            this.files_ignored_count = new Label("Files blocked: ?");
            this.threads_active = new Label("Crawlers active: ?");
            import std.conv : to;

            this.files_shown = new Label("Files shown: 0/" ~ to!string(UI_LIST_MAX_SIZE));
            h.packStart(files_indexed_count, false, false, 0);
            h.packStart(files_ignored_count, false, false, 0);
            h.packStart(threads_active, false, false, 0);
            h.packStart(files_shown, false, false, 0);
        }
        else
        {
            this.github_notice = new Label("");
            this.github_notice.setSelectable(true);
            this.github_notice.setJustify(GtkJustification.CENTER);
            this.github_notice.setHalign(GtkAlign.CENTER);
            this.github_notice.setMarkup("<a href=\"https://github.com/yatima1460/drill\">Drill</a> is maintained by <a href=\"https://www.linkedin.com/in/yatima1460/\">Federico Santamorena</a>" ~ " " ~ drillapi
                    .getVersion());

            h.packStart(github_notice, true, true, 0);
        }

        // file_icon.setIconName("file");

        // create second column with two renderers
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle("Name");
        column.setFixedWidth(400);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        CellRendererPixbuf file_icon = new CellRendererPixbuf();
        file_icon.setProperty("icon-name", "dialog-question");

        this.treeview.appendColumn(column);
        CellRendererText cell_text = new CellRendererText();
        column.packStart(file_icon, false);
        column.packStart(cell_text, true);
        column.addAttribute(cell_text, "text", Column.NAME);
        column.addAttribute(file_icon, "icon-name", Column.NAME_ICON);

        column = new TreeViewColumn();
        column.setTitle("Path");
        column.setFixedWidth(200);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.PATH);

        // create first column with text renderer
        column = new TreeViewColumn();
        column.setTitle("Size");
        this.treeview.appendColumn(column);
        column.setFixedWidth(50);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.SIZE);

        column = new TreeViewColumn();
        column.setTitle("Date Modified");
        column.setFixedWidth(200);
        column.setResizable(true);
        column.setSizing(GtkTreeViewColumnSizing.FIXED);

        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.DATE_MODIFIED);

        debug {
            column = new TreeViewColumn();
            column.setTitle("Found by crawler");
            column.setFixedWidth(200);
            column.setResizable(true);
            column.setSizing(GtkTreeViewColumnSizing.FIXED);

            this.treeview.appendColumn(column);
            cell_text = new CellRendererText();
            column.packStart(cell_text, false);
            column.addAttribute(cell_text, "text", Column.FOUND_BY_CRAWLER);
        }


        // v.packStart(mb, false, false, 0);
        v.packStart(search_input, false, false, 0);
        v.packStart(scroll, true, true, 0);
        v.packStart(h, false, true, 0);

        
        showAll();

        gdk.Threads.threadsAddTimeout(10, &threadIdleProcess, cast(void*) this);

        addOnDelete(delegate bool(Event event, Widget widget) {
            Logger.logInfo("Window started to close, stopping crawlers");
            drillapi.stopCrawlingSync();
            return false;
        });

        addOnKeyPress(delegate bool(GdkEventKey* event, Widget widget) {
            import gdk.Keysyms : GdkKeysyms;
            if (event.keyval == GdkKeysyms.GDK_Escape) {
                Logger.logInfo("ESC pressed, window is closing");
                drillapi.stopCrawlingSync();
                this.close();
                return true;
            }
            return false;
        });
    }
}
