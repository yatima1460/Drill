
#include <stdlib.h>
#include <assert.h>


#include "context.h"
#include "config.h"
#include "utils.h"
#include "meta.h"
#include "matching_functions.h"

#include <mntent.h>

void drill_wait_for_crawlers(struct drill_context drill_context)
{

    for (size_t i = 0; i < DRILL_MAX_MOUNTPOINTS; i++)
    {
        // FIXME: if current_thread == thread continue

#ifdef __linux__
        pthread_t thread = drill_context.threads[i];
#else
        thrd_t thread = drill_context.threads[i];
#endif

        int result;

#ifdef __linux__
    
#else
    thrd_join(&thread, &result);
#endif
        
        printf("Thread return %d at the end\n", result);
    }
}

struct drill_context drill_start_crawling(struct drill_config drill_config, char *search_value, void (*result_callback)(struct file_info file_info, void* user_object), void *user_object)
{
    assert(search_value != NULL);
    assert(result_callback != NULL);
    if (user_object == NULL)
        fprintf(stderr, "warning: user_object is null\n");


    struct drill_context ctx = {0};

    // string is a search token, nothing to do
    if (strcmp(search_value, DRILL_CONTENT_SEARCH_TOKEN) == 0)
    {
        return ctx;
    }

   

    bool (*matching_function)(char* file_path, char* search_string) = NULL;
    if (string_starts_with(search_value, DRILL_CONTENT_SEARCH_TOKEN))
    {
        //TODO:  matching_function = drill_is_file_content_matching_search;
        // c.searchValue = searchValue.split(":")[1];
    }
    else
    {
        matching_function = drill_is_file_name_matching_search;
        memcpy(ctx.search_value, search_value, strlen(search_value));
    }

   

    assert(ctx.search_value != NULL);
    assert(strlen(ctx.search_value) > 0);

    ctx.user_object = user_object;




    //drill_get_mountpoints()


    struct mntent *ent;
    FILE *aFile;

    aFile = setmntent("/proc/mounts", "r");
    if (aFile == NULL) 
    {
        perror("setmntent");
        exit(1);
    }
    while (NULL != (ent = getmntent(aFile))) {
        printf("%s %s\n", ent->mnt_fsname, ent->mnt_dir);
    }
    endmntent(aFile);



// #ifdef __linux__
//     pthread_create(&thread, NULL, crawler_run, &x);
// #else
//     thrd_create(&thread, crawler_run, NULL);
// #endif
}