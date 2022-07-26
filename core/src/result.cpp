



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
    dr.is_directory = 0;

    // if (!dr.is_directory)
    //     dr.file_size = e.file_size();
    dr.file_size = 0;

    auto str_size = sizeof(char)*strlen(path);
    dr.path = (char*)malloc(str_size);
    memcpy((char*)dr.path, path, str_size);

    struct stat rst;

    if (stat(path, &rst) == 0)
    {
        auto mod_time = rst.st_mtime;
        dr.file_size = rst.st_size;
        dr.last_write_time = mod_time;
    }

    return dr;

} // namespace Drill::result::result(std::filesystem::directory_entrye)
