#include "path_string.h"

#include <string.h>

struct drill_path_string drill_path_string_new(const char *path)
{
    struct drill_path_string path_string;
    strcpy(path_string.path, path);
    return path_string;
}


struct drill_path_string concat_paths(struct drill_path_string str1,struct drill_path_string str2 ) 
{
    char *finalString = NULL;
    size_t n = 0;

    if ( str1.path ) n += strlen( str1.path );
    if ( str2.path ) n += strlen( str2.path );

    if ( ( str1.path || str2.path ) && ( finalString = (char*)malloc( n + 1 ) ) != NULL )
    {
        *finalString = '\0';

        if ( str1.path ) strcpy( finalString, str1.path );
        if ( str2.path ) strcat( finalString, str2.path );
    }

    struct drill_path_string ps = drill_path_string_new(finalString);
    free(finalString);
    return ps;
}
