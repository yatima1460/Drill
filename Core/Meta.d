


static import std.process;


immutable(string) DUB_JSON = import("dub.json");
immutable(string) getDubStringValue(immutable(string) key)
{
    import std.json;
    JSONValue j = parseJSON(DUB_JSON);
    import std.conv : to;
    return j[key].str;
}
import std.datetime;

static this()
{
    import std.path : baseName;
    import std.file : thisExePath;
    
    //VERSION = baseName(thisExePath);
}

immutable(string) BUILD_TIME  = __TIMESTAMP__;
version (Travis) immutable(string) VERSION = import("TRAVIS_VERSION");
else immutable(string) VERSION = "LOCAL_BUILD";
immutable(string) AUTHOR_NAME = "Federico Santamorena";
immutable(string) AUTHOR_URL  = "https://www.linkedin.com/in/yatima1460/";
immutable(string) GITHUB_URL  = getDubStringValue("homepage");
immutable(string) WEBSITE_URL = "https://drill.software";

