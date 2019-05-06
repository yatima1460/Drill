module Drill;

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
import gtk.CellRendererToggle;
import gtk.ListStore;
import gtk.EditableIF;
import gdk.RGBA;
import gdk.Color;
import gtk.ApplicationWindow: ApplicationWindow;
import gdk.Threads;
import gtk.Label;
import gtk.Scrollbar;
import gtk.ScrolledWindow;

import std.array : split, join;
import std.process : executeShell;
import std.container: Array;
import std.algorithm : canFind;
import std.file : readText;
import std.algorithm.mutation : copy;
import std.algorithm;
import std.algorithm.iteration;
import std.file : DirEntry;
import std.concurrency : Tid;

import pango.PgFontDescription;
import std.stdio;


import Crawler : Crawler;


const string VERSION = "v0.1.1";
const uint WINDOW_WIDTH = 800;
const uint WINDOW_HEIGHT = 450;
const uint UI_BUFFER_SIZE = -1;


enum Column
{
    TYPE,
    NAME,
    PATH,
    DATE_MODIFIED
}

import core.thread;
import std.concurrency;

//global variable holding the mainwindow used to access it from C bindings



        /**
    * The idle callback invoked by GTK periodically when the
    * application main thread is not engaged in any processing.
    */
extern(C) static nothrow int threadIdleProcess(void* data) {
    //Don't let D exceptions get thrown from function
    // try{
        
        	try{
                	//  writeln("updating");
                     assert(data != null);
                    //  writeln(data);
                     DrillWindow mainWindow = cast(DrillWindow)data;
                    //  writeln(mainWindow);
		// receiveTimeout(dur!("msecs")( 0 ), (int value) 
        // {
        //     import std.conv : to;
			
                long ignored_total = 0;
                foreach(thread; mainWindow.threads)
                {
                    Array!DirEntry* thread_index = thread.grab_index();
                    ignored_total += thread.ignored_count;
                    assert(thread_index != null);
                    mainWindow.index ~= *thread_index;
                }




                  import std.conv:to;
                mainWindow.files_indexed_count.setText("Files indexed: "~to!string(mainWindow.index.length));
                mainWindow.files_ignored_count.setText("Files ignored: "~to!string(ignored_total));


                if (mainWindow.list_dirty)
                {
                    

                    // writeln("list updated");
                    mainWindow.liststore.clear();
                    if (mainWindow.search_string != "")
                    {
                        
                        

                            static import std.path;
                            auto results = mainWindow.index[].filter!(x => canFind(std.path.baseName(x.name),mainWindow.search_string));

                            int i = 0;
                            foreach (result; results)
                            {
                                mainWindow.appendRecord(result);
                                i++;
                                if (i == UI_BUFFER_SIZE) break;
                            }
                    }
                 
                    mainWindow.list_dirty = false;
                }
        //         //  writeln("updating done");
		// 	}
		// );
		// If thread is not running, return false so GTK removes it
		// and no longer calls it during idle processing.


        gdk.Threads.threadsAddTimeout(100,&threadIdleProcess, data);
		if (!mainWindow.running) {
			return 0;
		}
	} catch (Throwable t) {
		return 0;
	}
	return 1;
        // receiveTimeout(dur!("msecs")( 0 ), (int value) {
				  //TODO HERE

        //        
		// 	// }
		// // );

        //     return 1;
              

              


            
          //Thread.sleep( dur!("msecs")( 5000 ) );
        // If thread is not running, return false so GTK removes it
        // and no longer calls it during idle processing.


    //     if (!mainWindow.running) {
    //         return 0;
    //     }
    //     return 1;


    // } catch (Throwable t) {
    //     return 0;
    // }
   
}


// void countNumbers() {
// 	writeln("Thread running ");
// 	int count = 0;
// 	// mainWindow.running = true;
// 	bool stop = false;
// 	while (!stop) {
// 		count++;
// 		writeln("Current count: ",count);
// 		ownerTid.send(count);
// 		Thread.getThis().sleep(dur!("msecs")( 1000 ));
// 		receiveTimeout(dur!("msecs")( 0 ), (bool abort) {
// 				stop = abort;
// 			}
// 			);
// 	}
// 	writeln("Shutting down thread");
// 	// mainWindow.running = false;
// }


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

    void open_file(string path)
    {
        // if (de.isDir())
        // {

        //     // import subprocess
        //     // subprocess.Popen(['xdg-open', self.path])
        // }
        executeShell("xdg-open "~path);
    }

    void open_containing_folder()
    {
        //  import subprocess
        //         subprocess.Popen(['xdg-open', self.parent])
    }

    void appendRecord(DirEntry fi)
    {
        auto it = liststore.createIter();

        liststore.setValue(it, Column.TYPE, fi.isDir() ? "Folder" : "File");
        static import std.path;
        liststore.setValue(it, Column.NAME, std.path.baseName(fi.name));
        liststore.setValue(it, Column.PATH, std.path.dirName(fi.name));
        liststore.setValue(it, Column.DATE_MODIFIED, fi.timeLastModified().toString());
    }

     private void doubleclick(TreePath tp, TreeViewColumn tvc, TreeView tv)
    {
        TreeIter ti = new TreeIter();

        this.liststore.getIter(ti,tp);

        string path = this.liststore.getValueString(ti,Column.PATH);
        string name = this.liststore.getValueString(ti,Column.NAME);
        import std.path : chainPath;
        import std.array : array;
        open_file(chainPath(path,name).array);
        // writeln(tp.);
       
    }

    private void searchChanged(EditableIF ei)
    {
        writeln("Wrote input:" ~ ei.getChars(0, -1));
        this.search_string = ei.getChars(0, -1);
        this.list_dirty = true;
    }

    public this(Application application) 
    {
		super(application);
       // this.running = true;
       
        this.setTitle("Drill");

        list_dirty = false;

       
        this.liststore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING]);

        setDefaultSize(800, 450);
        setResizable(true);
        setPosition(GtkWindowPosition.CENTER);
        if (!setIconFromFile("assets/icon.png"))
        {
            //fallback to default GTK icon if it can't find its own
            setIconName("search");
        }

        
       
        this.blocklist = readText("assets/blocklists/global.txt").split("\n");



        this.treeview = new TreeView();
        this.treeview.addOnRowActivated(&doubleclick);

        Box v = new Box(GtkOrientation.VERTICAL, 8);
        Box h = new Box(GtkOrientation.HORIZONTAL, 8);

        



        add(v);

        Entry search_input = new Entry();

        ScrolledWindow scroll = new ScrolledWindow();

        scroll.add(this.treeview);
        
        search_input.addOnChanged(&searchChanged);


        this.files_indexed_count = new Label("Files indexed: ?");
         this.files_ignored_count = new Label("Files ignored: ?");
        h.packStart(files_indexed_count, false, false, 0);
 h.packStart(files_ignored_count, false, false, 0);

        // create first column with text renderer
        TreeViewColumn column = new TreeViewColumn();
        column.setTitle("Type");
        this.treeview.appendColumn(column);
        column.setFixedWidth(50);

        CellRendererText cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.TYPE);

        // create second column with two renderers
        column = new TreeViewColumn();
        column.setTitle("Name");
        column.setFixedWidth(300);
        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.NAME);

        column = new TreeViewColumn();
        column.setTitle("Path");
        column.setFixedWidth(200);
        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.PATH);

        column = new TreeViewColumn();
        column.setTitle("Date Modified");
        column.setFixedWidth(250);
        this.treeview.appendColumn(column);
        cell_text = new CellRendererText();
        column.packStart(cell_text, false);
        column.addAttribute(cell_text, "text", Column.DATE_MODIFIED);

     

        v.packStart(search_input, false, false, 0);
        v.packStart(scroll, true, true, 0);
        v.packStart(h, false, false, 0);

        this.treeview.setModel(this.liststore);
        showAll();


        auto ls = executeShell("df -h --output=target");
        if (ls.status != 0) {
            writeln("Can't retrieve mount points, will scan `/`");

        }
        else{

            gdk.Threads.threadsAddTimeout(100,&threadIdleProcess, cast(void*)this);
            // this.childTid = spawn(&countNumbers);
			
			// childTid = spawn(&countNumbers);

                
            Array!string mountpoints = Array!string();
            foreach(mountpoint; ls.output.split("\n"))
            {
                if (canFind(mountpoint,"/"))
                {
                    mountpoints ~= mountpoint;
                }
            }
            writeln("Mount points to scan:"~join(mountpoints[]," "));
            this.threads = Array!Crawler();






            foreach (mountpoint; mountpoints)
            {
                writeln("Starting thread for: ", mountpoint);
                Array!string crawler_exclusion_list = Array!string(blocklist);
         
                import std.array;
                 // for safety measure add the mount points minus itself to the exclusion list
                string[] cp_tmp = mountpoints[].filter!(x => x != mountpoint).map!(x => "^"~x~"$").array;
                writeln(join(cp_tmp," "));
                crawler_exclusion_list ~= cp_tmp;
                // assert mountpoint not in crawler_exclusion_list, "crawler mountpoint can't be excluded";
                
                auto crawler = new Crawler(mountpoint, crawler_exclusion_list);
                crawler.start();
                this.threads.insertBack(crawler);
            }
           

        } 


        
        // fill store with data
        // FileInfo fi = new FileInfo();
        // fi.type_str = "Folder";
        // fi.name = "OwO";
        // fi.path = "/";
        // fi.date_modified_str = "0";

    // appendRecord(DirEntry("/home/yatima1460/Downloads"));
    // appendRecord(DirEntry("/home/yatima1460/Downloads/icon.svg"));

        addOnDelete(delegate bool(Event event, Widget widget) {
            writeln("Close event");
            foreach (thread; threads)
            {
                thread.running = false;
            }
            foreach (thread; threads)
            {
                thread.join(false);
                writeln("Thread "~thread.root~ " stopped cleanly");
            }

            return false;
        });

    }
}

import gtk.Application: Application;
import gio.Application: GioApplication = Application;



int main(string[] args)
{
    std.concurrency.thisTid;
	auto application = new Application("me.santamorena.drill", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(delegate void(GioApplication app){ 
			new DrillWindow(application); 
		});
	return application.run(args);

    // Main.init(args);
    // new DrillWindow();
    // Main.run();
}
