#include "result.hpp"
#include <sys/types.h>
#include <sys/stat.h>
#ifndef WIN32
#include <unistd.h>
#endif

#ifdef WIN32
#define stat _stat
#endif

struct drill_result drill_result_new(std::filesystem::directory_entry e)
{
    struct drill_result dr{};
    dr.is_directory = e.is_directory();

    if (!dr.is_directory)
        dr.file_size = e.file_size();
    dr.path = std::string(e.path().string());

    struct stat rst;

    if (stat(dr.path.c_str(), &rst) == 0)
    {
        auto mod_time = rst.st_mtime;
        dr.last_write_time = mod_time;
    }

    return dr;

} // namespace Drill::result::result(std::filesystem::directory_entrye)
