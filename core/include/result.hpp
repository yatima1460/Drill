#pragma once

#include <filesystem>
#include <string>

namespace Drill
{

    namespace result
    {
        struct result
        {
            uintmax_t file_size;
            std::string path;
            std::filesystem::file_time_type last_write_time;
            bool is_directory;

            result(std::filesystem::directory_entry e)
            {
                is_directory = e.is_directory();

                if (!is_directory)
                    file_size = e.file_size();
                path = std::string(e.path().string());
                last_write_time = e.last_write_time();
            }
        };
    } // namespace result
} // namespace Drill
