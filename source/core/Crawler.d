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
    immutable(string) root;
    bool running;
    const(Regex!char[]) exclusion_list;
    const(Regex!char[]) priority_list;
    // Array!DirEntry* index;
    debug
    {
        long ignored_count;
    }

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

    this(immutable(string) root, const(Regex!char[]) exclusion_list,
            const(Regex!char[]) priority_list,
            void delegate(immutable(FileInfo) result) resultFound, immutable(string) search)
    {

        //TODO: invariant root contains /

        super(&run);
        this.root = root;
        this.exclusion_list = exclusion_list;
        this.priority_list = priority_list;
        // debug {
        //     if (this.exclusion_list.length == 0)
        //         logConsole(this ~ " has an empty exclusion list!");
        // }
        //this.index = new Array!DirEntry();
        this.search = search;

        resultCallback = resultFound;
    }

    pure void stopAsync() @safe @nogc
    {
        this.running = false;
    }

    void stopSync()
    {
        this.running = false;
        this.join();
    }

    // Array!DirEntry* grab_index()
    // {
    //     Array!DirEntry* i = this.index;
    //     this.index = new Array!DirEntry();
    //     return i;
    // }

    pure const override string toString() @safe
    {
        return "Thread(" ~ root ~ ")";
    }

    pure const bool isCrawling() @safe @nogc
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
            //index.insertBack(direntryroot);

            this.running = true;
            while (queue.length != 0)
            {
                Array!DirEntry* next_queue = new Array!DirEntry();

                import std.algorithm : sort;
                import std.array : array;
                import std.path : baseName;

                auto q = array(queue);

                bool myComp(DirEntry de1, DirEntry de2)
                {
                    auto d1 = baseName(de1.name);
                    auto d2 = baseName(de2.name);

                    import std.regex;
                    foreach (ref regexrule; this.priority_list)
                    {

                        RegexMatch!string mo = std.regex.match(d1, regexrule);
                        if (!mo.empty())
                            return true;
                    }
                    return false;

                }

                foreach (parent; sort!(myComp)(q))
                {
                    debug
                    {
                        logConsole(this.toString() ~ " parent:" ~ parent);
                    }
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

                                logConsole("[SYMLINK IGNORED]\t" ~ direntry.name);

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

                                    logConsole("[REGEX BLOCKED]\t" ~ direntry.name);

                                    debug
                                    {
                                        this.ignored_count++;
                                    }
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

                                logConsole("[DIRECTORY QUEUED]\t" ~ direntry.name);
                                f.isDirectory = true;
                            }
                            else
                            {
                                f.isFile = false;
                            }

                            // int[string] aa;

                            // index.insertBack(direntry);
                            import std.algorithm : canFind;
                            import std.path : baseName, dirName, extension;

                            // TODO split by space and search every token
                            import std.uni : toLower;
                            import std.string : split, strip;

                            const string fileNameLower = toLower(baseName(direntry.name));

                            //FIXME: filter and remove empty strings (if the user writes "a   b")
                            const string[] searchTokens = toLower(strip(search)).split(" ");
                            //writeln(searchTokens, fileNameLower);

                            foreach (token; searchTokens)
                            {
                                if (!canFind(fileNameLower, token))
                                {
                                    //writeln("skipping...");
                                    continue fileloop;
                                }

                            }

                            f.fullPath = direntry.name;
                            f.fileName = baseName(direntry.name);

                            f.fileNameLower = toLower(f.fileName);
                            f.containingFolder = dirName(direntry.name);
                            f.extension = extension(direntry.name);
                            import drill.core.utils : humanSize;

                            f.sizeString = humanSize(direntry.size);
                            import drill.core.utils : toDateString;

                            f.dateModifiedString = toDateString(direntry.timeLastModified());
                            if (running)
                                resultCallback(f);

                            logConsole("[FILE FOUND]\t" ~ direntry.name);
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
