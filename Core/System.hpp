
#include <vector>
#pragma once

#include <string>



namespace Drill::System
{

    using namespace std;
    
    vector<string> getMountpoints();


    std::string getHomeFolder();

    
    bool doesPathExist(const std::string &s);
}

