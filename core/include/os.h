#pragma once



#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "path_string.h"

/**
 * @brief Returns the current user's home folder
 *
 * @return string of the path to the home folder
 */
struct drill_path_string drill_os_user_folder();

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
bool drill_os_get_mountpoints(struct drill_path_string*, size_t* mountpoints);

#ifdef __cplusplus
}
#endif