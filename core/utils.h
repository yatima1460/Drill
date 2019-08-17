#pragma once


#include <stdlib.h>
#include <stdbool.h>
#include <string.h>


bool string_starts_with(const char *str, const char *pre)
{
    size_t lenpre = strlen(pre);
    size_t lenstr = strlen(str);
    return lenstr < lenpre ? false : memcmp(pre, str, lenpre) == 0;
}