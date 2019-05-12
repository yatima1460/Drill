module drill.core.crawler;

import std.container : Array;
import core.thread : Thread;
import std.stdio;
import std.file;
import std.file : DirEntry;
import drill.core.utils : logConsole;
import drill.core.fileinfo : FileInfo;

// debug
// {
//     import std.experimental.logger;
// }
import std.regex : Regex;

class Crawler : Thread
{
private:
    string root;
    bool running;
    Regex!char[] exclusion_list;
    Array!DirEntry* index;
    long ignored_count;
    void delegate(immutable(FileInfo) result) resultCallback;

    immutable(string) search;

public:
    // debug
    // {
    //     FileLogger log;
    // }

    // invariant(root != null);
    // invariant(root.length > 0);
    // invariant(resultCallback != null);
    // invariant(exclusion_list.length > 0);

    this(string root, Regex!char[] exclusion_list,
            void delegate(immutable(FileInfo) result) resultFound, immutable(string) search)
    {

        //TODO: invariant root contains /

        super(&run);
        this.root = root;
        this.exclusion_list = exclusion_list;
        // debug {
        //     if (this.exclusion_list.length == 0)
        //         logConsole(this ~ " has an empty exclusion list!");
        // }
        this.index = new Array!DirEntry();
        this.search = search;

        resultCallback = resultFound;
    }

    void stopAsync()
    {
        this.running = false;
    }

    void stopSync()
    {
        this.running = false;
        this.join();
    }

    Array!DirEntry* grab_index()
    {
        Array!DirEntry* i = this.index;
        this.index = new Array!DirEntry();
        return i;
    }

    override string toString()
    {
        return "Thread(" ~ root ~ ")";
    }

    bool isCrawling()
    {
        return this.running;
    }

private:
    void run()
    {
        import std.array : replace;

        debug
        {
            logConsole(this.toString() ~ " started");
        }

        Array!DirEntry* queue = new Array!DirEntry();
        try
        {
            DirEntry direntryroot = DirEntry(this.root);

            queue.insertBack(direntryroot);
            index.insertBack(direntryroot);

            this.running = true;
            while (queue.length != 0)
            {
                Array!DirEntry* next_queue = new Array!DirEntry();

                foreach (parent; *queue)
                {

                    try
                    {
                        DirIterator entries = dirEntries(parent, SpanMode.shallow, true);

                        fileloop: foreach (DirEntry direntry; entries)
                        {
                            if (!this.running)
                                return;
                            //logConsole(file.size);

                            if (direntry.isSymlink())
                            {

                                logConsole(direntry.name ~ " ignored because symlink");

                                continue fileloop;
                            }

                            import std.regex;

                            // logConsole("Working on:" ~ file.name);
                            foreach (ref regexrule; this.exclusion_list)
                            {

                                // matchAll() returns a range that can be iterated
                                // to get all subsequent matches.
                                RegexMatch!string mo = std.regex.match(direntry.name, regexrule);

                                if (!mo.empty())
                                {

                                    logConsole(
                                            direntry.name ~ " low priority because of regex rules");

                                    this.ignored_count++;

                                    continue fileloop;
                                }
                                else

                                {


                                    //logConsole(direntry.name ~ " added");
                                }

                            }

                            FileInfo f;
                            if (direntry.isDir())
                            {
                                next_queue.insertBack(direntry);

                                logConsole(direntry.name ~ " directory queued next");
                                f.isDirectory = true;
                            }
                            else
                            {
                                f.isFile = false;
                            }

                            // int[string] aa;


                            // index.insertBack(direntry);
                            import std.algorithm : canFind;
                              import std.path : baseName, dirName;

                            // TODO split by space and search every token
                            if (!canFind(baseName(direntry.name),search))
                                continue;

                          

                            f.fullPath = direntry.name;
                            f.fileName = baseName(direntry.name);
                            f.containingFolder = dirName(direntry.name);
                            import drill.core.utils : humanSize;

                            f.sizeString = humanSize(direntry.size);
                            import drill.core.utils : toDateString;

                            f.dateModifiedString = toDateString(direntry.timeLastModified());

                            resultCallback(f);

                            //logConsole(direntry.name ~ " added to global index");

                        }

                    }
                    catch (std.file.FileException e)
                    {

                        logConsole(e.msg);

                        continue;
                    }
                }

                queue = next_queue;
            }

        }
        catch (std.file.FileException e)
        {

            logConsole(e.msg);

            this.running = false;
            return;
        }
        this.running = false;

        logConsole("Thread for `" ~ root ~ "` finished its job");

    }

}
