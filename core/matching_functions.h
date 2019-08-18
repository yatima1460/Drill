#ifndef MATCHING_FUNCTIONS_H
#define MATCHING_FUNCTIONS_H

#include <stdbool.h>
#include <ctype.h>

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

bool drill_is_file_name_matching_search(char* file_path, char* search_string)
{
    assert(file_path != NULL);
    assert(search_string != NULL);

    char* file_name = basename(file_path);
    assert(file_name != NULL);

    // if (strlen(file_name) < strlen(search_string))
    //     return false;
    
    char* search_string_lower = malloc(sizeof(char)*strlen(search_string));
    assert(search_string_lower != NULL);
    for (size_t i = 0; i < strlen(search_string); i++)
    {
        search_string_lower[i] = tolower(search_string[i]);
    }

   // size_t strlen_file_name = strlen(file_name);
    //char* file_name_lower = malloc(sizeof(char)*strlen(file_name));
    // assert(file_name_lower != NULL);
    // for (size_t i = 0; i < strlen(file_name); i++)
    // {
    //     file_name_lower[i] = tolower(file_name[i]);
    // }
    
    // char* search_string_lower_trimmed = trimwhitespace(search_string_lower);

    // char * pch = strtok (search_string_lower_trimmed," ");
    // while (pch != NULL)
    // {
    //     if(strstr(file_name_lower,pch) != 0)
    //     {
    //         return false;
    //     }
    //     pch = strtok (NULL, " ");
    // }

    // free(search_string_lower);
    // free(file_name_lower);
    return true;
}


#endif