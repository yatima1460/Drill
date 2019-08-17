#ifndef CRAWLER_H
#define CRAWLER_H


#include <stdio.h>
#include <stdbool.h>




struct crawler_context
{
    char mountpoint[FILENAME_MAX];

    void (*result_callback)(struct file_info file_info, void *user_object);
    bool running;
};


void* crawler_run(void* c_ctx);

void crawler_stop_async(struct crawler_context c_ctx);

#endif