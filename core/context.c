
#include <stdlib.h>
#include <assert.h>
#include <dirent.h>

#include "context.h"
#include "config.h"
#include "utils.h"
#include "meta.h"
#include "matching_functions.h"
#include "crawler.h"

#ifdef __linux__
#   include <mntent.h>
#endif








void drill_wait_for_crawlers(struct drill_context drill_context)
{
    if (drill_context.threads_count == 0)
        fprintf(stderr, "warning: trying to wait when there is no need, 0 threads active\n");

    for (int i = 0; i < drill_context.threads_count; i++)
    {
        // FIXME: if current_thread == thread continue

#ifdef _WIN32
        thrd_t thread = drill_context.threads[i];
#else
        pthread_t thread = drill_context.threads[i];
#endif

#ifdef _WIN32
        int result = -999;
        thrd_join(&thread, &result);
        printf("[%s] returned %d at the join\n", drill_context.threads_context[i].mountpoint, (int)result);
#else
        void *retval = (void *)-999;
        pthread_join(thread, &retval);
        printf("[%s] returned %ld at the join\n", drill_context.threads_context[i].mountpoint, (unsigned long)retval);

#endif
    }
}

struct drill_context* drill_start_crawling(struct drill_config drill_config, char *search_value, void (*result_callback)(struct file_info file_info, void *user_object), void *user_object)
{
    assert(search_value != NULL);
    assert(result_callback != NULL);
    if (user_object == NULL)
        fprintf(stderr, "warning: user_object is null\n");

    struct drill_context* ctx = malloc(sizeof(struct drill_context));

    // string is a search token, nothing to do
    if (strcmp(search_value, DRILL_CONTENT_SEARCH_TOKEN) == 0)
    {
        return ctx;
    }

    bool (*matching_function)(char *file_path, char *search_string) = NULL;
    if (string_starts_with(search_value, DRILL_CONTENT_SEARCH_TOKEN))
    {
        //TODO:  matching_function = drill_is_file_content_matching_search;
        // c.searchValue = searchValue.split(":")[1];
    }
    else
    {
        matching_function = drill_is_file_name_matching_search;
        memcpy(ctx->search_value, search_value, strlen(search_value));
    }

    assert(ctx->search_value != NULL);
    assert(strlen(ctx->search_value) > 0);

    ctx->user_object = user_object;

//TODO: barrier
//TODO: if crawler in blocklist do not spawn

// get mountpoints and spawn the crawlers
#ifdef __linux__
    struct mntent *ent;
    FILE *aFile;

    aFile = setmntent("/proc/mounts", "r");
    if (aFile == NULL)
    {
        perror("setmntent");
        exit(1);
    }
    while (NULL != (ent = getmntent(aFile)))
    {
        //printf("%s\n", ent->mnt_dir);

        //struct crawler_context c_ctx = {0};

        

        strcpy(ctx->threads_context[ctx->threads_count].mountpoint, ent->mnt_dir);

        //printf("Crawler with mountpoint '%s' will be spawned now\n", ctx.threads_context[ctx.threads_count].mountpoint);

        pthread_t thread;
        if (pthread_create(&ctx->threads[ctx->threads_count], NULL, crawler_run, &ctx->threads_context[ctx->threads_count])  != 0 )
        {
            perror("pthread_create() error\n");
            exit(1);
        }
       
        ctx->threads_count++;
    }
    endmntent(aFile);
#elif __APPLE__
    DIR *d;
    struct dirent *dir;
    d = opendir("/Volumes");
    if (d)
    {
        while ((dir = readdir(d)) != NULL)
        {
            strcpy(ctx->threads_context[ctx->threads_count].mountpoint, dir->d_name);

            //printf("Crawler with mountpoint '%s' will be spawned now\n", ctx.threads_context[ctx.threads_count].mountpoint);

            pthread_t thread;
            if (pthread_create(&ctx->threads[ctx->threads_count], NULL, crawler_run, &ctx->threads_context[ctx->threads_count]) != 0)
            {
                perror("pthread_create() error\n");
                exit(1);
            }

            ctx->threads_count++;
        }
        closedir(d);
    }
#elif _WIN32
#warning windows thread spawning to do
#else
#error NOT SUPPORTED
#endif

    return ctx;

    // #ifdef __linux__
    //     pthread_create(&thread, NULL, crawler_run, &x);
    // #else
    //     thrd_create(&thread, crawler_run, NULL);
    // #endif
}