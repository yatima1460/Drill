#include "Engine.hpp"



void resultsBare()
{

}

using namespace Drill;

#include <signal.h>
#include <stdlib.h>
#include <stdio.h>

void my_handler(sig_atomic_t s)
{
    std::cout << "Stopping crawling..." << std::endl;
    exit(0); 
}
   
int main(int argc, char const *argv[])
{
    signal (SIGINT, my_handler);


 
    Engine context("owo");


    

    context.startDrilling();


    while(context.isCrawling())
    {
        const auto results = context.pickupAllResults();

        for (const auto result : results)
        {
            std::cout << result.path << std::endl;
        }
    }

    context.waitDrilling();

    /* code */
    return EXIT_SUCCESS;
}
