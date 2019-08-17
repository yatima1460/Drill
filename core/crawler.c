

#include "crawler.h"

#include <stdlib.h>

#include "meta.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

#include <assert.h>


#include <dirent.h>

#include <memory.h>

void elaborate_file(struct crawler_context *c_ctx, struct dirent *file, DIR *queue, unsigned int *queue_count)
{
    assert(c_ctx != NULL);
    assert(strlen(c_ctx->mountpoint) > 0);
    assert(file != NULL);
    assert(queue != NULL);
    assert(queue_count != NULL);
}

void crawl_directory(struct crawler_context *c_ctx, const char *popped_directory_fullpath, char **queue, unsigned int *queue_count)
{
    assert(c_ctx != NULL);
    assert(strlen(c_ctx->mountpoint) > 0);
    assert(popped_directory_fullpath != NULL);
    assert(strlen(popped_directory_fullpath) > 0);
    assert(queue != NULL);
    assert(queue_count != NULL);

    DIR *d = opendir(popped_directory_fullpath);
    
    free(popped_directory_fullpath);

    struct dirent *file = NULL;

    if (d)
    {

        while ((file = readdir(d)) != NULL)
        {
            if (c_ctx->running == false)
            {
                printf("Crawler '%s' is breaking file loop because requested exit\n", c_ctx->mountpoint);
                pthread_exit(0);
            }

            if (strcmp(file->d_name,".") == 0 || strcmp(file->d_name,"..") == 0)
            {
                continue;
            }

            printf("Crawler '%s' found the file '%s'\n", c_ctx->mountpoint,file->d_name);

            //elaborate_file(c_ctx, file, queue, queue_count);

            // strcpy(ctx.threads_context[ctx.threads_count].mountpoint, dir->d_name);

            // //printf("Crawler with mountpoint '%s' will be spawned now\n", ctx.threads_context[ctx.threads_count].mountpoint);

            // pthread_t thread;
            // if (pthread_create(&ctx.threads[ctx.threads_count], NULL, crawler_run, &ctx.threads_context[ctx.threads_count]) != 0)
            // {
            //     perror("pthread_create() error\n");
            //     exit(1);
            // }

            // ctx.threads_count++;
        }
        closedir(d);
    }
    else
    {
        fprintf(stderr, "[%s] failed to get shallow files\n", c_ctx->mountpoint);
    }
}

void *crawler_run(void *c_ctx_ptr)
{
    assert(c_ctx_ptr != NULL);
    struct crawler_context *c_ctx = (struct crawler_context *)c_ctx_ptr;
    assert(strlen(c_ctx->mountpoint) > 0);

    printf("Crawler '%s' started\n", c_ctx->mountpoint);

    c_ctx->running = true;

    /*
    Every Crawler will have all the other mountpoints in its blocklist
    In this way crawlers will not cross paths in the worst case scenario
    */
    //TODO: here

    char **queue = NULL;
    unsigned int queue_count = 0;

    queue = realloc(queue, queue_count + 1);
    char *dir_name_to_scan = malloc(FILENAME_MAX);
    memset(dir_name_to_scan, 0, FILENAME_MAX);
    strcpy(dir_name_to_scan, c_ctx->mountpoint);
    queue[queue_count] = dir_name_to_scan;
    queue_count++;

    while (queue_count != 0 && c_ctx->running)
    {
        char *popped_directory_fullpath = queue[--queue_count];
        assert(popped_directory_fullpath != NULL);
        assert(strlen(popped_directory_fullpath) > 0);

        crawl_directory(c_ctx, popped_directory_fullpath, queue, &queue_count);
    }
    free(queue);

    c_ctx->running = false;

    printf("Crawler '%s' finished its job\n", c_ctx->mountpoint);

    pthread_exit(0);
}

void crawler_stop_async(struct crawler_context c_ctx)
{
    printf("Crawler '%s' async stop requested\n", c_ctx.mountpoint);
    c_ctx.result_callback = NULL;
    c_ctx.running = false;
}