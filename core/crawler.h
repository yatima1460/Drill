#ifndef CRAWLER_H
#define CRAWLER_H


#include <stdio.h>
#include <stdbool.h>



#include "file_info.h"


struct crawler_context
{
    char mountpoint[FILENAME_MAX];
    void* user_object;
    void (*result_callback)(struct file_info file_info, void *user_object);
    bool running;
    bool (*matching_function)(char* file_path, char* search_string);
    char** queue;
    unsigned int queue_count;
    char search_string[FILENAME_MAX];
};


void* crawler_run(void* c_ctx);

void crawler_stop_async(struct crawler_context* const c_ctx);

#endif