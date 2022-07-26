#pragma once
#include <time.h>

#ifdef __cplusplus
extern "C"{
#endif
struct drill_result
{
    size_t file_size;
    const char *path;
    time_t last_write_time;
    int is_directory;
};


    struct drill_result drill_result_new(const char *path);
#ifdef __cplusplus
}
#endif