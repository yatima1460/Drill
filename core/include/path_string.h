#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include <limits.h>
#include <stdio.h>

struct drill_path_string
{
    char path[FILENAME_MAX];
};

struct drill_path_string drill_path_string_new(const char *path);

struct drill_path_string concat_paths(struct drill_path_string str1,struct drill_path_string str2 );

#ifdef __cplusplus
}
#endif