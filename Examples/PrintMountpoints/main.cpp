#include "System.hpp"

#include <iostream>


int main()
{
    using namespace std;
    const auto input = Drill::System::getMountpoints();

    for (const auto mount: input)
        cout << mount << endl;

    return EXIT_SUCCESS;
}