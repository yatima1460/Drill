

#include <string_utils.hpp>

#include <algorithm>
#include <cctype>
#include <sstream>
#include <string>
#include <vector>
#include <chrono>
#include <filesystem>

#include <fstream>
#include <iostream>
#include <iostream>
#include <sstream>

namespace Drill
{
    namespace string_utils
    {

        template <typename Out> void split(const std::string &s, char delim, Out result)
        {
            std::istringstream iss(s);
            std::string item;
            while (std::getline(iss, item, delim))
            {
                *result++ = item;
            }
        }

        std::vector<std::string> split(const std::string &s, char delim)
        {
            std::vector<std::string> elems;
            split(s, delim, std::back_inserter(elems));
            return elems;
        }

        bool tokenSearch(std::string main, std::string tokens_string)
        {
            auto tokens_vector = split(to_lower(tokens_string), ' ');

            auto main_lower = to_lower(main);

            // if all tokens no matter the order are inside main it's okay
            for (auto token : tokens_vector)
            {

                // if token not found
                if (main_lower.find(token) == std::string::npos)
                {
                    return false;
                }
            }
            return true;
        }

        std::string to_lower(const std::string &str)
        {
            std::string result = str;
            std::transform(str.begin(), str.end(), result.begin(), ::tolower);
            return result;
        }

        std::string time_to_string(const time_t &time)
        {

            return std::string(ctime(&time));
        }

        std::string size_to_string(size_t bytes)
        {
            	char *suffix[] = {"B", "KB", "MB", "GB", "TB"};
                char length = sizeof(suffix) / sizeof(suffix[0]);

                int i = 0;
                double dblBytes = bytes;

                if (bytes > 1024) {
                    for (i = 0; (bytes / 1024) > 0 && i<length-1; i++, bytes /= 1024)
                        dblBytes = bytes / 1024.0;
                }

                static char output[200];
                sprintf(output, "%.02lf %s", dblBytes, suffix[i]);
                return output;
        }

    } // namespace string_utils

} // namespace Drill