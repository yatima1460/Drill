#ifndef META_H
#define META_H

#define DRILL_NAME "Drill"

#define DRILL_AUTHOR_NAME "Federico Santamorena"

#define DRILL_AUTHOR_USERNAME "yatima1460"

#define DRILL_VCS "https://github.com/yatima1460/Drill"

#define DRILL_HOMEPAGE "https://drill.software"

// Token string to search INSIDE files
#define DRILL_CONTENT_SEARCH_TOKEN "content:"

// After this number they will just be ignored
#define DRILL_MAX_MOUNTPOINTS 256

// #define DRILL_MAX_DIRECTORY_QUEUE 1024

#define DRILL_VERSION "3.0.0"


// char path_separator()
// {
// #ifdef _WIN32
//     return '\\';
// #else
//     return '/';
// #endif
// }

#ifdef UNUSED
#elif defined(__GNUC__)
#define UNUSED(x) UNUSED_##x __attribute__((unused))
#elif defined(__LCLINT__)
#define UNUSED(x) /*@unused@*/ x
#else
#define UNUSED(x) x
#endif

#endif