
#include <sys/types.h>
#include <sys/stat.h>


#include <stdio.h>
#include <stdlib.h>

#include <spdlog/spdlog.h>

#include "../System.hpp"

using namespace std;

vector<string> Drill::System::getMountpoints()
{
    vector<string> mps;
   
    mps.push_back("C:");
        //TODO: blacklist here for ent->mnt_fsname
   
    
    return mps;
}

std::string sanitizePath(const std::string path)
{
   
    return path;
}

std::string Drill::System::getHomeFolder()
{
    std::string test(getenv("USERPROFILE"));
    return sanitizePath(test);
}

bool Drill::System::doesPathExist(const std::string &s)
{
    if (s.length() == 0)
        return false;
    auto path = sanitizePath(s);
    spdlog::trace("Checking if folder {0} exists", path);
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0);
}