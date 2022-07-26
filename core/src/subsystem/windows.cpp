
#include <sys/stat.h>
#include <sys/types.h>

#include <stdio.h>
#include <stdlib.h>

#include <spdlog/spdlog.h>

#include "os.h"

using namespace std;

vector<string> Drill::system::get_mountpoints()
{
    vector<string> mps;

    mps.push_back("C:");
    // TODO: blacklist here for ent->mnt_fsname

    return mps;
}

std::string sanitize_path(const std::string path) { return path; }

std::string Drill::system::get_current_user_home_folder()
{
    std::string test(getenv("USERPROFILE"));
    return sanitize_path(test);
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