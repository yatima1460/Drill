#include <context.h>
#include <config.h>
#include <meta.h>
#include <assert.h>
#include <unistd.h>    /* for getopt */

void results_bare(const struct file_info file_info, void * user_object) 
{
    printf("%s\n", file_info.fullpath);
}

void print_help()
{
    printf("%s v%s - %s\n", DRILL_NAME, DRILL_VERSION, DRILL_VCS);
    printf("-f FILENAME search in the filename\n");
    printf("-c CONTENT search in the content\n");
    // printf("-n max results number\n");
    printf("-d print modified date\n");
    // printf("-D print modified date (unix time)\n");
    printf("-s print size (human readable)\n");
    // printf("-S print size in bytes\n");
}

#include <log.h>

int main(const int argc, char  * const argv[]) 
{
    log_set_level(LOG_INFO);
    // int aflag = 0;
    // int bflag = 0;
    // char * cvalue = NULL;
    // int index;
    
    bool print_date = false;
    bool print_size = false;

    if (argc == 1)
    {
        print_help();
        return EXIT_SUCCESS;
    }
    
    // if (argc > 4)
    // {
    //     printf("%s v%s - %s\n", DRILL_NAME, DRILL_VERSION, DRILL_VCS);
    //     fprintf(stderr,"Oops, you gave more arguments than expected.\n");
    //     return EXIT_FAILURE;
    // }

    // if (argc > 2)
    // for(int i = 2; i < argc; ++i)
    // {
    //     if(!strcmp(argv[i], "-s") || !strcmp(argv[i], "--size"))
    //     {
    //         print_size = true;
    //         continue;
    //     }
    //     if(!strcmp(argv[i], "-d") || !strcmp(argv[i], "--date"))
    //     {
    //         print_date = true;
    //         continue;
    //     }
    // }



    // opterr = 0;

   
    int option;

    char* search_string;
    
    // int n_options = 0;

    while((option = getopt(argc, argv, "f:n:cds")) != -1)
    {
       
        switch (option) 
        {
            case 'f':
                search_string = optarg;
                printf("search string is: %s\n", search_string);
                break;
            case 'n':
                fprintf(stderr,"max number still not supported\n");
                abort();
            case 'd':
                printf("turning on date\n");
                print_date = true;
                break;
            case 's':
                printf("turning on size\n");
                print_size = true;
                break;
            case '?':
                print_help();
                fprintf(stderr,"Option '%s' is not recognized\n",  argv[optind]);
                return EXIT_FAILURE;
            case ':':
                print_help();
                fprintf(stderr,"Option '%s' needs a value\n",  argv[optind]);
                return EXIT_FAILURE;
            default:
                print_help();
                fprintf(stderr,"Error parsing arguments.\nThis is probably a bug of the software, submit it.\n");
                return EXIT_FAILURE;
        }
        // n_options++;
    }

    //TODO: error if extra arguments

    struct drill_config config;    
    struct drill_context * ctx = drill_start_crawling(config, search_string, &results_bare, NULL);
    assert(ctx != NULL);

    drill_wait_for_crawlers(ctx);

    return EXIT_SUCCESS;
}