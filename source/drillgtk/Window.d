module Drill.Window;

////////////////////////////////
////////// SETTINGS ////////////
////////////////////////////////

const string VERSION = "1.0.0rc1";

// Window size, also always centered in the screen
const uint WINDOW_WIDTH = 800;
const uint WINDOW_HEIGHT = 450;

// Maximum number of files to show
// -1 for infinite, be careful it could slow down the UI
const uint UI_LIST_MAX_SIZE = 1000;

////////////////////////////////
////////////////////////////////
////////////////////////////////

import std.array : split, join;
import std.process : executeShell;
import std.container : Array;
import std.algorithm : canFind;
import std.file : readText;
import std.algorithm.mutation : copy;
import std.file : DirEntry;
import std.concurrency : Tid;
import std.regex : Regex;

debug
{
    import std.experimental.logger : FileLogger;
}

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
import gdk.RGBA;
import gdk.Color;
import gtk.ApplicationWindow : ApplicationWindow;
import gdk.Threads;
import gtk.Label;
import gtk.Scrollbar;
import gtk.ScrolledWindow;
import gdk.Pixbuf;
import glib.GException;

import pango.PgFontDescription;

import std.stdio;
import std.algorithm;
import std.algorithm.iteration;
import core.thread;
import std.concurrency;

import drillcore.Crawler : Crawler;
import Drill.SearchEntry : SearchEntry;

enum Column
{
    // TYPE,
    NAME_ICON,
    NAME,
    PATH,
    SIZE,
    DATE_MODIFIED,
}

extern (C) static nothrow int threadIdleProcess(void* data)
{
    try
    {
        assert(data != null);
        DrillWindow mainWindow = cast(DrillWindow) data;
        long ignored_total = 0;
        foreach (ref thread; mainWindow.threads)
        {
            if (thread.isRunning() && thread.running == true)
            {
                Array!DirEntry* thread_index = thread.grab_index();
                ignored_total += thread.ignored_count;
                assert(thread_index != null);
                mainWindow.index ~= *thread_index;
            }

        }

        import std.conv : to;

        mainWindow.files_indexed_count.setText(
                "Files indexed: " ~ to!string(mainWindow.index.length));
        mainWindow.files_ignored_count.setText("Files ignored: " ~ to!string(ignored_total));
        import std.array;

        mainWindow.threads_active.setText("Threads active: " ~ to!string(
                array(mainWindow.threads[].filter!(x => x.running)).length));

        if (mainWindow.list_dirty)
        {

            // writeln("list updated");
            mainWindow.liststore.clear();
            if (mainWindow.search_string != "")
            {

                static import std.path;

                debug
                {
                    mainWindow.log.info("search for `" ~ mainWindow.search_string ~ "`...");
                }
                import std.array;

                auto results = array(mainWindow.index[].filter!(x => canFind(std.path.baseName(x.name),
                        mainWindow.search_string)));
                debug
                {
                    mainWindow.log.info("search for `" ~ mainWindow.search_string ~ "`... DONE");
                }
                int i = 0;
                debug
                {
                    mainWindow.log.info("adding " ~ to!string(results.length) ~ " results to UI...");
                }
                foreach (ref result; results)
                {
                    mainWindow.appendRecord(result);
                    i++;
                    if (i == UI_LIST_MAX_SIZE)
                        break;
                }
                mainWindow.files_shown.setText("Files shown: " ~ to!string(
                        i) ~ "/" ~ to!string(UI_LIST_MAX_SIZE));

                debug
                {
                    mainWindow.log.info("adding results to UI... DONE");
                }

            }
            else
            {
                mainWindow.files_shown.setText("Files shown: 0/" ~ to!string(UI_LIST_MAX_SIZE));

            }

            mainWindow.list_dirty = false;

        }
        //         //  writeln("updating done");
        // 	}
        // );
        // If thread is not running, return false so GTK removes it
        // and no longer calls it during idle processing.

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

    ListStore liststore;
    string search_string;
    TreeView treeview;
    Array!Crawler threads;
    string[] blocklist;
    Array!DirEntry index;
    bool running;
    private Tid childTid;
    Label files_indexed_count;
    Label files_ignored_count;
    bool list_dirty;
    debug
    {
        FileLogger log;
    }
    Entry search_input;
    Label threads_active;
    Label files_shown;

    void open_file(string path)
    {

        version (Windows)
        {
            const string[] args = ["explorer", path];
            spawnProcess(args, std.stdio.stdin, std.stdio.stdout,
                    std.stdio.stderr, null, std.process.Config.none, null);
        }
        version (linux)
        {
            const string[] args = ["xdg-open", path];
            spawnProcess(args, std.stdio.stdin, std.stdio.stdout,
                    std.stdio.stderr, null, std.process.Config.none, null);
        }
        version (OSX)
        {
            const string[] args = ["open", path];
            spawnProcess(args, std.stdio.stdin, std.stdio.stdout,
                    std.stdio.stderr, null, std.process.Config.none, null);
        }

    }

    void appendRecord(DirEntry fi)
    {
        TreeIter it = liststore.createIter();
        import std.conv : to;

        static import std.path;

        if (fi.isDir())
        {
            liststore.setValue(it, Column.NAME_ICON, "folder");
            liststore.setValue(it, Column.SIZE, "");
        }

        else
        {
            import drillcore.Utils : humanSize;

            liststore.setValue(it, Column.SIZE, humanSize(fi.size));

            liststore.setValue(it, Column.NAME_ICON, "text-x-preview");
            auto ext = std.path.extension(fi.name);
            if (ext != null)
            {
                string* p = (ext in this.iconmap);
                if (p !is null)
                {
                    auto icon_name = this.iconmap[ext];
                    assert(icon_name != null);
                    liststore.setValue(it, Column.NAME_ICON, icon_name);
                    debug
                    {
                        log.info("Setting icon to " ~ this.iconmap[ext]);
                    }

                }
            }

        }

        liststore.setValue(it, Column.NAME, std.path.baseName(fi.name));
        liststore.setValue(it, Column.PATH, std.path.dirName(fi.name));
        import drillcore.Utils : toDateString;

        liststore.setValue(it, Column.DATE_MODIFIED, toDateString(fi.timeLastModified()));

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
        open_file(chained);
        // TODO: open_file failed
    }

    private void searchChanged(EditableIF ei)
    {
        debug
        {
            log.info("Wrote input:" ~ ei.getChars(0, -1));
        }
        this.search_string = ei.getChars(0, -1);
        this.list_dirty = true;
    }

    string[string] iconmap;

    public this(Application application)
    {
        import std.file : dirEntries, SpanMode;

        auto filetypes_file = dirEntries(DirEntry("../../assets/filetypes"), SpanMode.shallow, true);

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

        super(application);
        this.setTitle("Drill");
        setDefaultSize(800, 450);
        setResizable(true);
        setPosition(GtkWindowPosition.CENTER);

        debug
        {
            log = new FileLogger("logs/GTKThread.log");
        }

        list_dirty = false;
        this.liststore = new ListStore([
                GType.STRING, GType.STRING, GType.STRING, GType.STRING,
                GType.STRING
                ]);

        try
        {
            setIconFromFile("../../assets/icon.png");
        }
        catch (GException ge)
        {
            //fallback to default GTK icon if it can't find its own
            debug
            {
                log.warning("Can't find program icon, will fallback to default GTK one!");
            }
            setIconName("search");
        }

        import std.file : FileException;

        try
        {
            import std.file : dirEntries, SpanMode;

            auto blocklists_file = dirEntries(DirEntry("../../assets/blocklists"),
                    SpanMode.shallow, true);

            foreach (string partial_blocklist; blocklists_file)
            {
                this.blocklist ~= readText(partial_blocklist).split("\n");
            }
        }
        catch (FileException fe)
        {
            this.blocklist = [];
        }

        this.treeview = new TreeView();
        this.treeview.addOnRowActivated(&doubleclick);

        Box v = new Box(GtkOrientation.VERTICAL, 8);
        Box h = new Box(GtkOrientation.HORIZONTAL, 8);

        add(v);

        search_input = new SearchEntry();

        ScrolledWindow scroll = new ScrolledWindow();

        scroll.add(this.treeview);

        search_input.addOnChanged(&searchChanged);

        this.files_indexed_count = new Label("Files indexed: ?");
        this.files_ignored_count = new Label("Files blocked: ?");
        this.threads_active = new Label("Threads active: ?");
        import std.conv : to;

        this.files_shown = new Label("Files shown: 0/" ~ to!string(UI_LIST_MAX_SIZE));
        h.packStart(files_indexed_count, false, false, 0);
        h.packStart(files_ignored_count, false, false, 0);
        h.packStart(threads_active, false, false, 0);
        h.packStart(files_shown, false, false, 0);

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

        v.packStart(search_input, false, false, 0);
        v.packStart(scroll, true, true, 0);
        v.packStart(h, false, false, 0);

        this.treeview.setModel(this.liststore);
        showAll();

        //df catches network mounted drives like NFS
        //so don't use lsblk here
        auto ls = executeShell("df -h --output=target");

        if (ls.status != 0)
        {
            debug
            {

                log.error("Can't retrieve mount points, will scan `/`");
            }
            // TODO: fallback to `/` if can't retrieve mount points
        }
        else
        {
            import std.array;

            gdk.Threads.threadsAddTimeout(10, &threadIdleProcess, cast(void*) this);
            // this.childTid = spawn(&countNumbers);

            // childTid = spawn(&countNumbers);

            Array!string mountpoints = array(ls.output.split("\n").filter!(x => canFind(x, "/")));

            debug
            {

                log.info("Mount points to scan:" ~ join(mountpoints[], " "));
            }
            this.threads = Array!Crawler();

            foreach (ref mountpoint; mountpoints)
            {
                debug
                {
                    log.info("Starting thread for: ", mountpoint);
                }
                Array!string crawler_exclusion_list = Array!string(blocklist);

                // for safety measure add the mount points minus itself to the exclusion list
                string[] cp_tmp = mountpoints[].filter!(x => x != mountpoint)
                    .map!(x => "^" ~ x ~ "$")
                    .array;
                debug
                {
                    log.info(join(cp_tmp, " "));
                }
                crawler_exclusion_list ~= cp_tmp;
                // assert mountpoint not in crawler_exclusion_list, "crawler mountpoint can't be excluded";

                import std.regex;

                debug
                {
                    log.info("Compiling Regex...");
                }
                Regex!char[] regexes = crawler_exclusion_list[].map!(x => regex(x)).array;
                debug
                {
                    log.info("Compiling Regex... DONE");
                }
                auto crawler = new Crawler(mountpoint, regexes);
                crawler.start();
                this.threads.insertBack(crawler);
            }

        }

        addOnDelete(delegate bool(Event event, Widget widget) {
            debug
            {
                log.info("Window started to close");
            }
            foreach (ref thread; threads)
            {
                debug
                {
                    log.info(thread.toString() ~ ".running set to false");
                }
                thread.running = false;
            }
            foreach (ref thread; threads)
            {
                debug
                {
                    log.info("Waiting for thread " ~ thread.toString() ~ " to stop");
                }
                thread.join(false);
                debug
                {
                    log.info(thread.toString() ~ " stopped cleanly");
                }
            }

            return false;
        });

    }
}

import gtk.Application : Application;
import gio.Application : GioApplication = Application;
