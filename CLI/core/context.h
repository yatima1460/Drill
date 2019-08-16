



struct drill_context
{
    char[FILENAME_MAX] search_value;
    thrd_t[256] threads;
    void* user_object;
}


void drill_stop_crawling_async(struct drill_context*);

struct drill_context drill_start_crawling(struct drill_config* drill_config, char* search_value, void (*result_callback)(int), void* user_object);

uint drill_active_crawlers_count(struct drill_context* drill_context);

void drill_wait_for_crawlers(struct drill_context* drill_context);

void drill_stop_crawling_sync(struct drill_context*);

struct drill_context drill_start_crawling(struct drill_config* drill_config*, char* search_value, void (*result_callback)(int), void* user_object);