

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


void crawl_directory(struct crawler_context* c_ctx, struct dirent* popped_directory, struct dirent** queue, unsigned int* queue_count)
{
    assert(c_ctx != NULL);
    assert(popped_directory != NULL);
    assert(queue != NULL);
    assert(queue_count != NULL);


    
    DIR *d = opendir(popped_directory->d_name);
    
    struct dirent *dir;

    if (d)
    {
        while ((dir = readdir(d)) != NULL)
        {
            if (c_ctx->running == false)
            {
                printf("Crawler '%s' is breaking fiel loop because requested exit\n", c_ctx->mountpoint);
                pthread_exit(0);
            }
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
        fprintf(stderr,"Trying to get shallow files of '%s' failed.\n",popped_directory->d_name);
    }
    
}

void *crawler_run(void *c_ctx_ptr)
{
    assert(c_ctx_ptr != NULL);

    struct crawler_context* c_ctx = (struct crawler_context *)c_ctx_ptr;

    printf("Crawler '%s' started\n", c_ctx->mountpoint);

    c_ctx->running = true;

    /*
    Every Crawler will have all the other mountpoints in its blocklist
    In this way crawlers will not cross paths in the worst case scenario
    */
    //TODO: here


    struct dirent* queue[DRILL_MAX_DIRECTORY_QUEUE] = {0};
    unsigned int queue_count = 0;


    DIR *d;
    
    d = opendir(c_ctx->mountpoint);
    if (d)
    {
        // struct dirent* dir = readdir(d);
        queue[queue_count++] = readdir(d);
        closedir(d);
    }
    else
    {
        fprintf(stderr,"error: can't read mountpoint '%s'\n", c_ctx->mountpoint);
        c_ctx->running = false;
        pthread_exit(1);
    }
    

    while (queue_count != 0 && c_ctx->running)
    {
        struct dirent* popped_directory = queue[--queue_count];
        assert(popped_directory != NULL);

        crawl_directory(c_ctx, popped_directory, queue, &queue_count);
    }


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