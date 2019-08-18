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

bool drill_is_file_name_matching_search(const char* const file_path, const struct dirent *const file, const char* const  search_string)
{
    assert(errno == 0);
    assert(file_path != NULL);
    assert(search_string != NULL);
    

    // convert search string to lower case
    char* search_string_lower = malloc(sizeof(char)*strlen(search_string));
    if (errno != 0)
    {
        fprintf(stderr,"[drill_is_file_name_matching_search] malloc failed with string '%s' with error: %s\n",search_string,strerror(errno));
        abort();
    }
    assert(search_string_lower != NULL);
    for (int i = 0; search_string[i]; i++)
        search_string_lower[i] = tolower(search_string[i]);
   
    // convert file name to lower case
    char* file_name_lower = malloc(sizeof(char)*strlen(file->d_name));
    if (errno != 0)
    {
        fprintf(stderr,"[drill_is_file_name_matching_search] malloc failed with string '%s' with error: %s\n",search_string,strerror(errno));
        abort();
    }
    assert(file_name_lower != NULL);
    for (int i = 0; file->d_name[i]; i++)
        file_name_lower[i] = tolower(file->d_name[i]);
  
    //printf("comparing '%s' with '%s'\n", file_name_lower, search_string_lower);
    
    //size_t strlen_file_name = strlen(file_name);
    // if (errno != 0)
    // {
    //     fprintf(stderr,"[drill_is_file_name_matching_search] strlen failed with string '%s' with error: %s\n",file_name,strerror(errno));
    //     abort();
    // }


   // return strstr(file_name_lower,search_string_lower);

    
    char* search_string_lower_trimmed = trimwhitespace(search_string_lower);

    char * pch = strtok (search_string_lower_trimmed," ");
    while (pch != NULL)
    {
        if(strstr(file_name_lower,pch) == 0)
        {
            free(search_string_lower);
            free(file_name_lower);
            return false;
        }
        pch = strtok (NULL, " ");
    }

    free(search_string_lower);
    free(file_name_lower);
    return true;
}


#endif