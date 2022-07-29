#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include <time.h>
#include <limits.h>

struct drill_result
{
    size_t file_size;
    char path[PATH_MAX];
    time_t last_write_time;
    int is_directory;
};


struct drill_result drill_result_new(const char *path);

#ifdef __cplusplus
}
#endif