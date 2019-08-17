



#include "crawler.h"

#include <stdlib.h>

#ifdef _WIN32 
#   include <threads.h>
#else
#   include <pthread.h>
#endif

void* crawler_run(void* c_ctx)
{

    printf("Crawler '%s' started\n", ((struct crawler_context*)c_ctx)->mountpoint);


    
   pthread_exit(0);
}