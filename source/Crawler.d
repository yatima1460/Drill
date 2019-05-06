module Crawler;

import std.container : Array;
import core.thread : Thread;
import std.stdio;
import std.file;
import std.file : DirEntry;
import std.experimental.logger;
import std.regex : Regex;

class Crawler : Thread
{
    string root;
    bool running;
    Regex!char[] exclusion_list;
    Array!DirEntry* index;
    long ignored_count;
    FileLogger log;

    this(string root, Regex!char[] exclusion_list)
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
           import std.array : replace;
        log = new FileLogger("logs/"~replace(root,"/","_")~".log");
        writeln(this.toString()~" started");
        Array!DirEntry* queue = new Array!DirEntry();

        queue.insertBack(DirEntry(this.root));

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
                         log.trace(direntry.name ~ " ignored because symlink");
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
                            

                            log.trace(direntry.name ~ " low priority because of regex rules");
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
                         log.trace(direntry.name ~ " directory queued next");
                    }

                   

                    index.insertBack(direntry);
                     log.trace(direntry.name ~ " added to global index");
                }
            }

            queue = next_queue;
        }
        this.running = false;
        writeln("Thread for `" ~ root ~ "` finished its job");

    }

}
