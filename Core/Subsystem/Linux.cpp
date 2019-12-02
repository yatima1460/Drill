

#include "../System.hpp"
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <mntent.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <spdlog/spdlog.h>

using namespace std;

vector<string> Drill::System::getMountpoints()
{
    vector<string> mps;
    struct mntent *ent;
    FILE *aFile;

    aFile = setmntent("/proc/mounts", "r");
    if (aFile == nullptr) {
        // perror("setmntent");
        // mps.push_back("/");
        return mps;
    }
    while (nullptr != (ent = getmntent(aFile))) {
        mps.push_back(ent->mnt_dir);
        //TODO: blacklist here for ent->mnt_fsname
      
    }
    endmntent(aFile);
    return mps;
}

    std::string sanitizePath(const std::string path)
    {
        auto pathCpy = path;
        if (pathCpy[0] == '~')
            pathCpy = std::string(getenv("HOME"))+path.substr(1); 
        return pathCpy;
    }

std::string Drill::System::getHomeFolder()
{
    return sanitizePath("~");
}



bool Drill::System::doesPathExist(const std::string &s)
{
    if (s.length() == 0) 
        return false;
    auto path = sanitizePath(s);
    spdlog::trace("Checking if folder {0} exists", path);
    struct stat buffer;
    return (stat (path.c_str(), &buffer) == 0);
}