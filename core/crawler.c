

#include "crawler.h"

#include <stdlib.h>

#include "meta.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

#include <assert.h>

#define __USE_MISC 1
#include <dirent.h>

#include <memory.h>
#include <errno.h>

/*
    The string will be copied and added to the queue
*/
void crawler_add_to_queue(struct crawler_context *const c_ctx, const char *const string)
{
    assert(errno == 0);
    assert(c_ctx != NULL);
    assert(string != NULL);
    assert(strlen(string) > 0);
#ifdef _WIN32
    assert(string[1] == ':');
    assert(string[2] == '\\');
    // TODO: check range of valid Windows drives letters
#else
    assert(string[0] == '/');
#endif


        
    size_t realloc_size = sizeof(char *) * (c_ctx->queue_count + sizeof(char *));
    c_ctx->queue = realloc(c_ctx->queue, realloc_size);
    if (errno != 0)
    {
        fprintf(stderr,"[%s] realloc failed while adding item allocating %d bytes with error: %s\n",c_ctx->mountpoint,realloc_size,strerror(errno));
        abort();
    }
        
    assert(c_ctx->queue != NULL);
    size_t malloc_size = sizeof(char) * FILENAME_MAX;
    c_ctx->queue[c_ctx->queue_count] = malloc(malloc_size);
    if (errno != 0)
    {
        fprintf(stderr,"[%s] malloc failed while adding item allocating %d bytes with error: %s\n",c_ctx->mountpoint,malloc_size,strerror(errno));
        abort();
    }
    assert(c_ctx->queue[c_ctx->queue_count] != NULL);
    strcpy(c_ctx->queue[c_ctx->queue_count], string);
    c_ctx->queue_count++;
}

char *const crawler_pop_item(struct crawler_context *const c_ctx)
{
    assert(errno == 0);
    assert(c_ctx != NULL);
    assert(c_ctx->queue_count > 0);
    char *popped = c_ctx->queue[c_ctx->queue_count - 1];
    assert(popped != NULL);
#ifndef NDEBUG
    c_ctx->queue[c_ctx->queue_count - 1] = NULL;
#endif
    size_t realloc_size = sizeof(char *) * (sizeof(char *)*c_ctx->queue_count - sizeof(char *));
    c_ctx->queue = realloc(c_ctx->queue, realloc_size);
    if (errno != 0)
    {
        fprintf(stderr,"[%s] realloc failed while popping out and setting the new size to %d bytes with error: %s\n",c_ctx->mountpoint,realloc_size,strerror(errno));
        abort();
    }
    c_ctx->queue_count--;
    return popped;
}

void elaborate_file(const struct crawler_context *const c_ctx, const char *const current_directory, const struct dirent *const file)
{
    assert(errno == 0);
    assert(c_ctx != NULL);
    assert(strlen(c_ctx->mountpoint) > 0);
    assert(current_directory != NULL);
    assert(strlen(current_directory) > 0);
#ifdef _WIN32
    assert(current_directory[1] == ':');
    assert(current_directory[2] == '\\');
    // TODO: check range of valid Windows drives letters
#else
    assert(current_directory[0] == '/');
#endif
    assert(file != NULL);
    assert(strlen(file->d_name) > 0);

    // #ifndef NDEBUG
    // for (size_t i = 0; i < *queue_count; i++)
    // {
    //     assert(queue[i] != NULL);
    //     assert(strlen(queue[i]) != 0);
    // }
    // #endif

    char full_path[FILENAME_MAX] = {0};
    strcpy(full_path, current_directory);
    assert(strcmp(full_path,current_directory) == 0);
    if (strcmp(full_path, "/") != 0)
        strcat(full_path, "/");
    strcat(full_path, file->d_name);

    /* + 2 because of the '/' and the terminating 0 */
    // char *full_path = malloc(strlen(current_directory) + strlen(file->d_name) + 2);
    // assert(full_path != NULL);

    // if (strcmp(current_directory,"/") == 0)
    //     sprintf(full_path, "%s%s", current_directory, file->d_name);
    // else
    //     sprintf(full_path, "%s/%s", current_directory, file->d_name);

    // printf("full_path: '%s'\n", full_path);
    /* use fullpath */

    // strcat(full_path, '\0');

    if (file->d_type == DT_LNK)
    {
        //free(full_path);
        return;
    }
        

    if (file->d_type == DT_DIR)
    {
        // TODO: if in regex blocklist return

        // TODO: if in priority insert front of queue, else insert back

        // *queue = realloc(*queue, *queue_count + 1);

        // char *dir_name_to_scan = malloc(FILENAME_MAX);
        // memset(dir_name_to_scan, 0, FILENAME_MAX);
        // strcpy(dir_name_to_scan, file->d_name);

        // *queue[*queue_count] = dir_name_to_scan;
        // (*queue_count)++;

        // assert(c_ctx->queue != NULL);
        // c_ctx->queue = realloc(c_ctx->queue, c_ctx->queue_count+1);
        // c_ctx->queue[c_ctx->queue_count] = malloc(sizeof(char)*FILENAME_MAX);
        // strcpy(c_ctx->queue[c_ctx->queue_count], full_path);
        // c_ctx->queue_count++;

        crawler_add_to_queue(c_ctx, full_path);
        // if (*queue_count < DRILL_MAX_DIRECTORY_QUEUE)
        // {
        //     assert(strlen(c_ctx->mountpoint) > 0);
        //     strcpy(queue + FILENAME_MAX * *queue_count, full_path);
        //     assert(*(queue + FILENAME_MAX * *queue_count) != NULL);
        //     assert(strlen(queue + FILENAME_MAX * *queue_count) > 0);
        //     (*queue_count)++;
        // }
        // else
        // {
        //     fprintf(stderr, "[%s] error: reached maximum queue count\n", c_ctx->mountpoint);
        // }
    }

    /*
        The file (normal file or folder) does match the search:
        we send it to the callback result function
    */

    assert(c_ctx->matching_function != NULL);
    if ((*c_ctx->matching_function)(full_path, file, c_ctx->search_string))
    {
        struct file_info file_info;
        strcpy(file_info.name, file->d_name);
        strcpy(file_info.fullpath, full_path);

        if (c_ctx->result_callback != NULL)
        {
            (*c_ctx->result_callback)(file_info, c_ctx->user_object);
        }
        else
        {
            printf("[%s] warning: result_callback is null\n", c_ctx->mountpoint);
        }
    }

    //free(full_path);
}

void crawl_directory(const struct crawler_context *const c_ctx, const char *const popped_directory_fullpath)
{
    assert(errno == 0);
    assert(c_ctx != NULL);
    assert(strlen(c_ctx->mountpoint) > 0);
    assert(popped_directory_fullpath != NULL);
    assert(strlen(popped_directory_fullpath) > 0);

    // #ifndef NDEBUG
    // for (size_t i = 0; i < *queue_count; i++)
    // {
    //     assert(queue[i] != NULL);
    //     assert(strlen(queue[i]) != 0);
    // }
    // #endif

    const DIR *const d = opendir(popped_directory_fullpath);
    if (errno != 0)
    {
        fprintf(stderr,"[%s] opendir failed while reading '%s' with error: %s\n",c_ctx->mountpoint,popped_directory_fullpath,strerror(errno));
        errno = 0;
        return;
    }

    const struct dirent *file = NULL;

    if (d)
    {

        while ((file = readdir(d)) != NULL)
        {
            if (errno != 0)
            {
                fprintf(stderr,"[%s] readdir failed while reading '%s' with error: %s\n",c_ctx->mountpoint,file->d_name,strerror(errno));
                abort();
            }
            if (c_ctx->running == false)
            {
                printf("[%s] is breaking file loop because requested exit\n", c_ctx->mountpoint);
                pthread_exit(0);
            }

            if (strcmp(file->d_name, ".") == 0 || strcmp(file->d_name, "..") == 0)
            {
                continue;
            }

            //printf("Crawler '%s' found the file '%s'\n", c_ctx->mountpoint,file->d_name);

            elaborate_file(c_ctx, popped_directory_fullpath, file);

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
        fprintf(stderr, "[%s] failed to get shallow files of '%s', error is: '%s'\n", c_ctx->mountpoint, popped_directory_fullpath, strerror(errno));
    }
    //memset(queue+FILENAME_MAX**queue_count, 0, FILENAME_MAX);
}

void *crawler_run(void *c_ctx_ptr)
{
  
    assert(c_ctx_ptr != NULL);
    struct crawler_context *const c_ctx = (struct crawler_context *const)c_ctx_ptr;
    assert(strlen(c_ctx->mountpoint) > 0);

    printf("[%s] crawler started\n", c_ctx->mountpoint);

    c_ctx->running = true;

    /*
    Every Crawler will have all the other mountpoints in its blocklist
    In this way crawlers will not cross paths in the worst case scenario
    */
    //TODO: here

    // queue = realloc(queue, queue_count + 1);

    // char *dir_name_to_scan = malloc(FILENAME_MAX);
    // memset(dir_name_to_scan, 0, FILENAME_MAX);
    assert(c_ctx->queue == NULL);
    assert(c_ctx->queue_count == 0);
    crawler_add_to_queue(c_ctx, c_ctx->mountpoint);

    
    // char* nigga = crawler_pop_item(c_ctx);
    // assert(strcmp(nigga,c_ctx->mountpoint) == 0);
    // pthread_exit(0);

    while (c_ctx->queue_count != 0 && c_ctx->running)
    {
        const char *const popped_directory_fullpath = crawler_pop_item(c_ctx);
        assert(popped_directory_fullpath != NULL);
        assert(strlen(popped_directory_fullpath) > 0);
#ifdef _WIN32
        assert(popped_directory_fullpath[1] == ':');
        assert(popped_directory_fullpath[2] == '\\');
        // TODO: check range of valid Windows drives letters
#else
        assert(popped_directory_fullpath[0] == '/');
#endif

        crawl_directory(c_ctx, popped_directory_fullpath);
    }
    //free(queue);

    c_ctx->running = false;

    printf("[%s] finished its job\n", c_ctx->mountpoint);

    pthread_exit(0);
}

void crawler_stop_async(struct crawler_context *const c_ctx)
{
    printf("[%s] async stop requested\n", c_ctx->mountpoint);
    c_ctx->result_callback = NULL;
    c_ctx->running = false;
}