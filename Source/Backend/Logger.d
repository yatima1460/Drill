
module Logger;



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

    LogLevel globalLevel;


    static this()
    {
        debug
        {
            setLogLevel(LogLevel.Debug);
        }
        else
        {
            setLogLevel(LogLevel.Info);
        }
    }

public:

    LogLevel getLogLevel()
    {
        return globalLevel;
    } 

    void setLogLevel(LogLevel level)
    {
        globalLevel = level;
    }

    void logDebug(string message, string channel=__FUNCTION__)
    {
        log(LogLevel.Debug,message,channel);
    }

    void logError(string message, string channel=__FUNCTION__)
    {
        log(LogLevel.Error,message,channel);
    }

    void logFatal(string message, string channel=__FUNCTION__)
    {
        log(LogLevel.Fatal,message,channel);
    }


    void logTrace(string message, string channel=__FUNCTION__)
    {
        log(LogLevel.Trace,message,channel);
    }

    void logWarning(string message, string channel=__FUNCTION__)
    {
        log(LogLevel.Warning,message,channel);
    }

    void logInfo(string message, string channel=__FUNCTION__)
    {
        log(LogLevel.Info,message,channel);
    }

    import std.conv : to;

    void log(LogLevel level, string message, string channel)
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




