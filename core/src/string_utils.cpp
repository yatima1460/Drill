

#include <string_utils.hpp>

#include <vector>
#include <string>
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

        bool tokenSearch(std::string main, std::string tokens_string) { 
            auto tokens_vector = split(tokens_string, ' ');

            // if all tokens no matter the order are inside main it's okay
            for (auto token : tokens_vector) {
            
                // if token not found
                if (main.find(token) == std::string::npos) {
                    return false;
                }
            }
            return true;
        }
    } // namespace string_utils
} // namespace Drill