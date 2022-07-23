#pragma once

#include <filesystem>
#include <string>

struct FileInfo
{
    // std::string name;
    // std::string fullPath;
    uintmax_t file_size;
    std::string path;
    std::filesystem::file_time_type last_write_time;
    bool is_directory;


    FileInfo(std::filesystem::directory_entry e)
    {
        is_directory = e.is_directory();

        if (!is_directory)
            file_size = e.file_size();
        path = std::string(e.path().c_str());
        last_write_time = e.last_write_time();
    }
};