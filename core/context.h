#ifndef CONTEXT_H
#define CONTEXT_H


#include <stdlib.h>

#include <stdio.h>

// TODO: __STDC_NO_THREADS__

#ifdef _WIN32 
#   include <threads.h>
#else
#   include <pthread.h>
#endif

#include "meta.h"

#include "file_info.h"
#include "config.h"

#include "crawler.h"

struct drill_context
{
    char search_value[FILENAME_MAX];

    struct crawler_context threads_context[DRILL_MAX_MOUNTPOINTS];

#ifdef _WIN32 
    thrd_t threads[DRILL_MAX_MOUNTPOINTS];
#else
    pthread_t threads[DRILL_MAX_MOUNTPOINTS];
#endif


    unsigned int threads_count;

    void* user_object;
};





struct drill_context drill_start_crawling(struct drill_config drill_config, char* search_value, void (*result_callback)(struct file_info file_info, void* user_object), void* user_object);

unsigned int drill_active_crawlers_count(struct drill_context);

void drill_stop_crawling_async(struct drill_context);

void drill_stop_crawling_sync(struct drill_context);

void drill_wait_for_crawlers(struct drill_context);





#endif