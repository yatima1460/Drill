#pragma once


#include <string>
#include <vector>

#include "path_string.h"


namespace Drill::system
{


    

    /**
     * @brief Returns the current user's home folder
     *
     * @return string of the path to the home folder
     */
    struct drill_path_string get_current_user_home_folder();

    // bool doesPathExist(const std::string &s);
} // namespace Drill::system

/**
 * @brief Opens a file using the underlying os implementation
 * 
 * @param path file to open
 */
void drill_os_open(struct drill_path_string path);

/**
 * @brief Returns all the drives or mountpoints
 *
 * @return List of strings containing the mountpoints
 */
std::vector<struct drill_path_string> drill_os_get_mountpoints();