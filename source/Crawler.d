module Crawler;

import std.container : Array;
import core.thread : Thread;
import std.stdio;
import std.file;
import std.file : DirEntry;

class Crawler : Thread
{
    string root;
    bool running;
    Array!string exclusion_list;
    Array!DirEntry* index;
    long ignored_count;

    this(string root, Array!string exclusion_list)
    {
        super(&run);
        this.root = root;
        this.exclusion_list = exclusion_list;
        this.index = new Array!DirEntry();

    }

    Array!DirEntry* grab_index()
    {
        Array!DirEntry* i = this.index;
        this.index = new Array!DirEntry();
        return i;
    }

    override string toString()
    {
        return "Thread("~root~")";
    }

private:
    void run()
    {
        writeln(this.toString()~" started");
        Array!DirEntry* queue = new Array!DirEntry();

        queue.insertBack(DirEntry(this.root));

        this.running = true;
        while (queue.length != 0)
        {
            Array!DirEntry* next_queue = new Array!DirEntry();

            foreach (parent; *queue)
            {

                auto filelist = dirEntries(parent, SpanMode.shallow, false);

                import std.array : join;

                // writeln("Thread "~root~" files in root are: ");

                fileloop: foreach (file; filelist)
                {
                    if (!this.running)
                        return;
                    //writeln(file.size);

                    import std.regex;

                    // writeln("Working on:" ~ file.name);
                    foreach (regexrule; this.exclusion_list)
                    {
                        auto r = regex(regexrule);

                        // matchAll() returns a range that can be iterated
                        // to get all subsequent matches.
                        RegexMatch!string mo = std.regex.match(file.name, r);

                        if (!mo.empty())
                        {
                            // writeln(file.name ~ " ignored");
                            this.ignored_count++;
                            continue fileloop;
                        }
                        else

                        {
                            // writeln(file.name ~ " added");
                        }

                    }

                    if (file.isDir())
                    {
                        next_queue.insertBack(file);
                    }

                    index.insertBack(file);
                }
            }

            queue = next_queue;
        }
        writeln("Thread for `" ~ root ~ "` finished its job");

    }

}
