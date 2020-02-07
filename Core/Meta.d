



immutable(string) DUB_JSON = import("dub.json");
immutable(string) getDubStringValue(immutable(string) key)
{
    import std.json;
    JSONValue j = parseJSON(DUB_JSON);
    import std.conv : to;
    return j[key].str;
}


immutable(string) VERSION = import("DRILL_VERSION");
immutable(string) BUILD_TIME  = __TIMESTAMP__;
immutable(string) AUTHOR_NAME = "Federico Santamorena";
immutable(string) AUTHOR_URL  = "https://www.linkedin.com/in/yatima1460/";
immutable(string) GITHUB_URL  = getDubStringValue("homepage");
immutable(string) WEBSITE_URL = "https://drill.software";



debug
{
        
    import std.conv : to;
    import std.compiler : name, vendor, version_major, version_minor, D_major;
    immutable(string) CREDITS_STRING = " " ~ name ~ " Compiler Vendor: " ~ to!string(
            vendor) ~ " Compiler version: v" ~ to!string(version_major) ~ "." ~ to!string(
            version_minor) ~ " D version:" ~ to!string(D_major);

   

}
else
{
   immutable(string) CREDITS_STRING = "Drill v"~VERSION~" is maintained by <a href=\"" ~ AUTHOR_URL ~ "\">" ~ AUTHOR_NAME ~ "</a> and it's open source under " ~ getDubStringValue("license") ~ ", for source code and new releases click <a href=\""~GITHUB_URL~"\">here</a>";

}

// version (LDC) immutable(string) COMPILER = "LLVM " ~ COMPILER_META;
// version (DigitalMars) immutable(string) COMPILER = "DMD" ~ COMPILER_META;
// version (GNU) immutable(string) COMPILER = "GNU" ~ COMPILER_META;
// version (SDC) immutable(string) COMPILER = "SDC" ~ COMPILER_META;


// immutable(string) CREDITS_STRING = "<a href=\"" ~ GITHUB_URL ~ "\">Drill</a>" ~ " is maintained by " ~ " " v" ~ VERSION ~ "-" ~ COMPILER;

