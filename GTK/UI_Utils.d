import std.functional : memoize;
import std.typecons : Tuple;
import std.experimental.logger;
import std.uni : toLower;
import std.path : extension;
import std.process : executeShell;

import std.process : spawnProcess;
import std.stdio : stdin, stdout, stderr;
import std.process : Config;
import std.process : executeShell;
import std.array : split;
import std.conv : to;

import GTKBinds;



/**
Opens a file using the current system implementation for file associations


*/
void openFile(immutable string fullpath)
{
    // FIXME: return false when no file association
    import std.stdio : stdin, stdout, stderr;
    import std.process : browse, Config, executeShell, spawnProcess;

    try
    {
        version (Windows)
        {
            spawnProcess(["explorer", fullpath], null, Config.detached, null);
        }
        version (linux)
        {
            immutable auto ext = toLower(extension(fullpath));

            // FIXME: folders ending in .AppImage are broken
            switch (ext)
            {
                case ".appimage":
                    info("File "~fullpath~" detected as .AppImage");

                    // Check if AppImage bit executable is set
                    immutable auto stat = executeShell("stat -c \"%a\""~fullpath);
                    if (stat.status != 0)
                    {

                        // Drill knows it's executable, run it
                        if (to!int(stat.output[0]) % 2 == 1)
                        {

                        }
                      
                    }
                    else
                    {
                        // We don't know, let's warn the user and run it
                        import std.string : toStringz;
                        auto dialog = gtk_message_dialog_new (null,
                                                        GtkDialogFlags.GTK_DIALOG_MODAL,
                                                        GtkMessageType.GTK_MESSAGE_ERROR,
                                                        GtkButtonsType.GTK_BUTTONS_OK,

                                                        toStringz("Drill couldn't find out if '"~fullpath~"' AppImage is executable, will try to run it anyways..."));
                        gtk_dialog_run (cast(GtkDialog*)dialog);
                        gtk_widget_destroy (dialog);

                    }
                    immutable auto cmd = executeShell("chmod +x "~fullpath);
                    if (cmd.status != 0)
                    {
                        error("Can't set AppImage '"~fullpath~"' as executable.");
                        import std.string : toStringz;
                        auto dialog = gtk_message_dialog_new (null,
                                                        GtkDialogFlags.GTK_DIALOG_MODAL,
                                                        GtkMessageType.GTK_MESSAGE_ERROR,
                                                        GtkButtonsType.GTK_BUTTONS_CLOSE,

                                                        toStringz("Can't set AppImage '"~fullpath~"' as executable."));
                        gtk_dialog_run (cast(GtkDialog*)dialog);
                        gtk_widget_destroy (dialog);
                       
                    }
                    spawnProcess([fullpath], null, Config.detached, null);
                 
                    break;
                default:
                    info("Generic file "~fullpath~", will use xdg-open.");
                    () @trusted { browse(fullpath); } ();
                   
            }
        }
        version (OSX)
        {
            spawnProcess(["open", fullpath], null, Config.detached, null);
        }
    }
    catch (Exception e)
    {
        error(e.msg);
        import std.string : toStringz;
        auto dialog = gtk_message_dialog_new (null,
                                        GtkDialogFlags.GTK_DIALOG_MODAL,
                                        GtkMessageType.GTK_MESSAGE_ERROR,
                                        GtkButtonsType.GTK_BUTTONS_CLOSE,
                                        toStringz(e.msg));
        gtk_dialog_run (cast(GtkDialog*)dialog);
        gtk_widget_destroy (dialog);
    }
}
