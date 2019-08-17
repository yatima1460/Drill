



#include "crawler.h"

#include <stdlib.h>


void* crawler_run(void* c_ctx)
{

    printf("Crawler '%s' started\n", ((struct crawler_context*)c_ctx)->mountpoint);


    
   pthread_exit(0);
}