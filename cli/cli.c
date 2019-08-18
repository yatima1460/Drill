#include <context.h>
#include <config.h>
#include <meta.h>

#include <assert.h>


void results_bare(struct file_info file_info, void* user_object)
{
    
    printf("%s \n",file_info.fullpath);
}





int main(int argc, char const *argv[])
{
    printf("%s v%s - %s\n", DRILL_NAME, DRILL_VERSION, DRILL_VCS);
    struct drill_config config;

    
    struct drill_context* ctx = drill_start_crawling(config,argv[1],&results_bare,NULL);
    assert(ctx != NULL);

    drill_wait_for_crawlers(*ctx);


    return EXIT_SUCCESS;
}