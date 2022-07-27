



#include "result.h"

#include <sys/types.h>
#include <sys/stat.h>
#ifndef WIN32
#include <unistd.h>
#endif
#include <stdlib.h> 
#include <memory.h>
#include <string.h>

#ifdef WIN32
#define stat _stat
#endif

struct drill_result drill_result_new(const char* path)
{
    struct drill_result dr;
    memset(&dr, 0, sizeof(dr));
    
    dr.is_directory = 0;
    dr.file_size = 0;
    memset(dr.path, 0, PATH_MAX);
    strcpy(dr.path, path);
 
    // dr.name = strdup(path);


    // auto str_size = sizeof(char)*strlen(path);
    

    struct stat rst;
    if (stat(path, &rst) == 0)
    {
        auto mod_time = rst.st_mtime;

        // size in bytes
        dr.file_size = rst.st_size;

        // modified time
        dr.last_write_time = mod_time;

        // bitmask containing the type of file
        dr.is_directory = S_ISDIR(rst.st_mode);
    }

    return dr;

} // namespace Drill::result::result(std::filesystem::directory_entrye)
