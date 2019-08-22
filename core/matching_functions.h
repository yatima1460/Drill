#ifndef MATCHING_FUNCTIONS_H
#define MATCHING_FUNCTIONS_H

#include <stdbool.h>
#include <ctype.h>

#include <errno.h>

// Note: This function returns a pointer to a substring of the original string.
// If the given string was allocated dynamically, the caller must not overwrite
// that pointer with the returned value, since the original pointer must be
// deallocated using the same allocator with which it was allocated.  The return
// value must NOT be deallocated using free() etc.
char *trimwhitespace(char *str)
{
    char *end;

    // Trim leading space
    while(isspace((unsigned char)*str)) str++;

    if(*str == 0)  // All spaces?
        return str;

    

    // Trim trailing space
    end = str + strlen(str) - 1;
    while(end > str && isspace((unsigned char)*end)) end--;

    // Write new null terminator character
    end[1] = '\0';

    return str;
}

/*
    Returns a new allocated string all lowercase
*/
char* new_string_to_lowercase(const char* const string)
{
    size_t string_length = strlen(string);
    char* const string_lower = malloc(sizeof(char)*(string_length+1));
    if (errno != 0)
    {
        fprintf(stderr,"[drill_is_file_name_matching_search] malloc failed with string '%s' with error: %s\n",string,strerror(errno));
        abort();
    }
    for (size_t i = 0; i < string_length; i++)
        string_lower[i] = tolower(string[i]);
    string_lower[string_length] = '\0';
    return string_lower;
}

#include "log.h"

bool drill_is_file_name_matching_search(const char* const file_path, const struct dirent *const file, const char* const  search_string)
{
    assert(errno == 0);
    assert(file_path != NULL);
    assert(search_string != NULL);
    
    const char* const search_string_lower = new_string_to_lowercase(search_string);
    const char* const file_name_lower = new_string_to_lowercase(file->d_name);
   
    char* search_string_lower_trimmed = trimwhitespace(search_string_lower);

    char * pch = strtok (search_string_lower_trimmed," ");
    while (pch != NULL)
    {
// #ifndef NDEBUG
//     if (strstr(file_name_lower," ") != NULL)
//     {
//          if(strcmp(search_string_lower_trimmed,trimwhitespace(pch)) != 0)
//          log_fatal("%s %s",search_string_lower_trimmed,trimwhitespace(pch));
//     }
       
// #endif
        if(strstr(file_name_lower,pch) == NULL)
        {
            
            log_trace("'%s' does not match sub-token: '%s'\n",file_name_lower,pch);
            free(search_string_lower);
            free(file_name_lower);
            return false;
        }
        pch = strtok (NULL, " ");
    }
    log_trace("'%s' matches sub-token: '%s'",file_name_lower,pch);
    free(search_string_lower);
    free(file_name_lower);
    return true;
}


#endif