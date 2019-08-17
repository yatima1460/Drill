#ifndef CRAWLER_H
#define CRAWLER_H


#include <stdio.h>



struct crawler_context
{
    char mountpoint[FILENAME_MAX];

};


void* crawler_run(void* c_ctx);


#endif