
#include <mntent.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "os.h"
#include "path_string.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <assert.h>

struct drill_path_string* drill_os_get_mountpoints(struct drill_path_string *mountpoints_array, size_t *mountpoints_count)
{
    
    assert(mountpoints_count != NULL);

    struct mntent *ent;
    FILE *aFile;

    aFile = setmntent("/proc/mounts", "r");
    if (aFile == NULL)
    {
        perror("setmntent");
        exit(1);
    }

    size_t mounts_count = 0;
    mountpoints_array = NULL;

    while (NULL != (ent = getmntent(aFile)))
    {
        mountpoints_array = realloc(mountpoints_array, sizeof(struct drill_path_string) * (mounts_count + 1));
        mountpoints_array[mounts_count] = drill_path_string_new(ent->mnt_dir);
        mounts_count++;
    }
    endmntent(aFile);

    *mountpoints_count = mounts_count;
}

// std::string sanitize_path(const std::string &path)
// {
//     auto pathCpy = path;
//     if (pathCpy[0] == '~')
//         pathCpy = std::string(getenv("HOME")) + path.substr(1);
//     return pathCpy;
// }

// struct drill_path_string drill_os_user_folder() { return drill_path_string_new(sanitize_path("~").c_str());
// }

char *getConcatString(const char *str1, const char *str2)
{
    char *finalString = NULL;
    size_t n = 0;

    if (str1)
        n += strlen(str1);
    if (str2)
        n += strlen(str2);

    if ((str1 || str2) && (finalString = (char *)malloc(n + 1)) != NULL)
    {
        *finalString = '\0';

        if (str1)
            strcpy(finalString, str1);
        if (str2)
            strcat(finalString, str2);
    }

    return finalString;
}

void drill_os_open(struct drill_path_string path)
{
    //  FIXME: input sanitization
    system(concat_paths(drill_path_string_new("xdg-open \""), concat_paths(path, drill_path_string_new("\"")))
               .path);
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

