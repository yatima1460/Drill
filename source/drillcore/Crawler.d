module drill.core.crawler;

import std.container : Array;
import core.thread : Thread;
import std.stdio;
import std.file;
import std.file : DirEntry;

debug
{
    import std.experimental.logger;
}
import std.regex : Regex;

class Crawler : Thread
{
    string root;
    bool running;
    Regex!char[] exclusion_list;
    Array!DirEntry* index;
    long ignored_count;
    debug
    {
        FileLogger log;
    }

    this(string root, Regex!char[] exclusion_list)
    {
        super(&run);
        this.root = root;
        this.exclusion_list = exclusion_list;
        this.index = new Array!DirEntry();

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

private:
    void run()
    {
        import std.array : replace;

        debug
        {
            log = new FileLogger("logs/" ~ replace(root, "/", "_") ~ ".log");
        }
        writeln(this.toString() ~ " started");
        Array!DirEntry* queue = new Array!DirEntry();
        auto direntryroot = DirEntry(this.root);
        queue.insertBack(direntryroot);
        index.insertBack(direntryroot);

        this.running = true;
        while (queue.length != 0)
        {
            Array!DirEntry* next_queue = new Array!DirEntry();

            foreach (parent; *queue)
            {

                fileloop: foreach (DirEntry direntry; dirEntries(parent, SpanMode.shallow, true))
                {
                    if (!this.running)
                        return;
                    //writeln(file.size);

                    if (direntry.isSymlink())
                    {
                        debug
                        {
                            log.trace(direntry.name ~ " ignored because symlink");
                        }

                        continue fileloop;
                    }

                    import std.regex;

                    // writeln("Working on:" ~ file.name);
                    foreach (ref regexrule; this.exclusion_list)
                    {

                        // matchAll() returns a range that can be iterated
                        // to get all subsequent matches.
                        RegexMatch!string mo = std.regex.match(direntry.name, regexrule);

                        if (!mo.empty())
                        {

                            debug
                            {
                                log.trace(direntry.name ~ " low priority because of regex rules");
                            }
                            this.ignored_count++;

                            continue fileloop;
                        }
                        else

                        {

                            //writeln(direntry.name ~ " added");
                        }

                    }

                    if (direntry.isDir())
                    {
                        next_queue.insertBack(direntry);
                        debug
                        {
                            log.trace(direntry.name ~ " directory queued next");
                        }

                    }

                    int[string] aa;
                    index.insertBack(direntry);
                    debug
                    {
                        log.trace(direntry.name ~ " added to global index");
                    }

                }
            }

            queue = next_queue;
        }
        this.running = false;
        writeln("Thread for `" ~ root ~ "` finished its job");

    }

}
