



enum LogLevel
{
    Trace,
    Debug,
    Info,
    Error,
    Warning,
    Fatal
}



final class Logger
{

static:

    debug
    {
        immutable(LogLevel) globalLevel = LogLevel.Debug;
    }
    else
    {
        immutable(LogLevel) globalLevel = LogLevel.Error;
    }

    // version (release)
    // {
    //     immutable(LogLevel) globalLevel = LogLevel.Info;
    // }
    // version (profile)
    // {
    //     immutable(LogLevel) globalLevel = LogLevel.Info;
    // }
    // version (trace)
    // {
    //     immutable(LogLevel) globalLevel = LogLevel.Trace;
    // }
    // version (debug_normal)
    // {
    //     immutable(LogLevel) globalLevel = LogLevel.Debug;
    // }

public:

    immutable(LogLevel) getLogLevel() pure @nogc @safe
    {
        return globalLevel;
    } 

    void logTrace(immutable(string) message, immutable(string) channel=__PRETTY_FUNCTION__) @system
    {
        debug
        {
            log(LogLevel.Trace,message,channel);
        }
    }

    void logDebug(immutable(string) message, immutable(string) channel=__PRETTY_FUNCTION__) @system
    {
        debug
        {
            log(LogLevel.Debug,message,channel);
        }
    }

    void logInfo(immutable(string) message, immutable(string) channel=__PRETTY_FUNCTION__) @system
    {
        log(LogLevel.Info,message,channel);
    }

    void logWarning(immutable(string) message, immutable(string) channel=__PRETTY_FUNCTION__) @system
    {
        log(LogLevel.Warning,message,channel);
    }

    void logError(immutable(string) message, immutable(string) channel=__PRETTY_FUNCTION__) @system
    {
        log(LogLevel.Error,message,channel);
    }

    void logFatal(immutable(string) message, immutable(string) channel=__PRETTY_FUNCTION__) @system
    {
        log(LogLevel.Fatal,message,channel);
    }

    import std.conv : to;

    void log(LogLevel level, immutable(string) message, immutable(string) channel) @system
    {
        synchronized
        {
            if (level >= globalLevel)
            {
                import std.datetime.systime : Clock;
                auto currentTime = Clock.currTime();
                auto timeString = currentTime.toISOExtString();
                import std.stdio : writeln;
                writeln("["~timeString~"]["~to!string(level)~"]["~channel~"] "~message);
            }
        }
    }




}




