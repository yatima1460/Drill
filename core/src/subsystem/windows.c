
#include <sys/stat.h>
#include <sys/types.h>

#include <stdio.h>
#include <stdlib.h>



#include "os.h"




bool drill_os_get_mountpoints(struct drill_path_string *mountpoints_array, size_t *mountpoints_count)
{
    *mountpoints_count = 0;
    mountpoints_array = realloc(mountpoints_array, sizeof(struct drill_path_string) * (*mountpoints_count + 1));
    mountpoints_array[*mountpoints_count] = drill_path_string_new("C:\\");


}



struct drill_path_string drill_os_user_folder()
{
    return drill_path_string_new(getenv("USERPROFILE"));
}

// bool Drill::system::doesPathExist(const std::string &s)
// {
//     if (s.length() == 0)
//         return false;
//     auto path = sanitize_path(s);
//     spdlog::trace("Checking if folder {0} exists", path);
//     struct stat buffer;
//     return (stat(path.c_str(), &buffer) == 0);
// }