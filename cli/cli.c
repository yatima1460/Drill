#include <context.h>
#include <config.h>
#include <meta.h>

void result_callback(struct file_info file_info, void* user_object)
{

}


int main()
{
    printf("%s v%s - %s\n", DRILL_NAME, DRILL_VERSION, DRILL_VCS);
    struct drill_config config;
    struct drill_context ctx = drill_start_crawling(config,"owo",&result_callback,NULL);


    drill_wait_for_crawlers(ctx);


    return EXIT_SUCCESS;
}