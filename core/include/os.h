#pragma once

#include <string>
#include <vector>

namespace Drill::system
{

    /**
     * @brief Returns the all the drives or mountpoints connected
     *
     * @return List of strings containing the mountpoints
     */
    std::vector<std::string> get_mountpoints();

    /**
     * @brief Returns the current user's home folder
     *
     * @return string of the path to the home folder
     */
    std::string get_current_user_home_folder();

    // bool doesPathExist(const std::string &s);
} // namespace Drill::system
