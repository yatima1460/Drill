
#include <mntent.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <stdio.h>
#include <stdlib.h>
#include<unistd.h>
#include<stdio.h>
#include<sys/types.h>
#include<stdlib.h>
#include<sys/wait.h>
#include <stdio.h>
#include <string.h>
#include "os.h"

using namespace std;

#include <fstream>
#include <iostream>

struct Mount
{
    std::string device;
    std::string destination;
    std::string fstype;
    std::string options;
    int dump;
    int pass;
};

std::ostream &operator<<(std::ostream &stream, const Mount &mount)
{
    return stream << mount.fstype << " device \"" << mount.device << "\", mounted on \"" << mount.destination
                  << "\". Options: " << mount.options << ". Dump:" << mount.dump << " Pass:" << mount.pass;
}

vector<string> Drill::system::get_mountpoints()
{
    vector<string> mps;

    struct mntent *ent;
    FILE *aFile;

    aFile = setmntent("/proc/mounts", "r");
    if (aFile == NULL)
    {
        perror("setmntent");
        exit(1);
    }
    while (NULL != (ent = getmntent(aFile)))
    {
        mps.push_back(ent->mnt_dir);
    }
    endmntent(aFile);


    return mps;

}

std::string sanitize_path(const std::string &path)
{
    auto pathCpy = path;
    if (pathCpy[0] == '~')
        pathCpy = std::string(getenv("HOME")) + path.substr(1);
    return pathCpy;
}

std::string Drill::system::get_current_user_home_folder() { return sanitize_path("~"); }


char * getConcatString( const char *str1, const char *str2 ) 
{
    char *finalString = NULL;
    size_t n = 0;

    if ( str1 ) n += strlen( str1 );
    if ( str2 ) n += strlen( str2 );

    if ( ( str1 || str2 ) && ( finalString = (char*)malloc( n + 1 ) ) != NULL )
    {
        *finalString = '\0';

        if ( str1 ) strcpy( finalString, str1 );
        if ( str2 ) strcat( finalString, str2 );
    }

    return finalString;
}

void drill_os_open(const char *path)
{
    //  FIXME: input sanitization
    system(getConcatString("xdg-open \"",getConcatString(path,"\"") ));
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


// Estrogens are 