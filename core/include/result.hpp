#pragma once

#include <filesystem>
#include <string>





struct drill_result
{
    uintmax_t file_size;
    std::string path;
    time_t last_write_time;
    bool is_directory;
};


struct drill_result drill_result_new(std::filesystem::directory_entry e);