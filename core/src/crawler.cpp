#include <assert.h>
#include <filesystem>

#include <iostream>
#include <thread>

#include "spdlog/spdlog.h"

#include "crawler.hpp"
#include "string_utils.hpp"
#include "result.h"

namespace Drill
{

    namespace crawler
    {
        namespace fs = std::filesystem;
        void scan(std::string mountpoint, std::string searchValue,
                  void (*resultsCallback)(struct drill_result results), std::shared_ptr<spdlog::logger> console)
        {

            console->info("Crawler started {0}", mountpoint);

            std::vector<std::string> queue;
            queue.push_back(mountpoint);

            /*
            README!!!
            If we reach this point the directory we are scanning is already confirmed
            to be scanned, a directory should be confirmed BEFORE adding it to the queue,
            so the queue doesn't get saturated of useless directories that will be excluded later
            */

            /*
            README!!!
            only directories should be checked against blocklists,
            files will slow down and it's useless to scan them,
            who cares if a user will see an useless file that is actually in the blocklists
            but we care because they slow down the Drill crawling
            */

            // console->warn("Scanning {0}", mountpoint);
            while (!queue.empty())
            {
                auto directory = queue.back();
                queue.pop_back();

                console->trace("Scanning {0}", directory);

                try
                {
                    for (const auto &entry : fs::directory_iterator(directory))
                    {

                        if (entry.is_symlink() || entry.is_block_file() || entry.is_character_file() ||
                            entry.is_fifo() || entry.is_socket() || entry.is_other())
                        {
                            console->trace(
                                "Special symlink/block/character/fifo/socket/other file ignored: `{0}`",
                                entry.path().string());
                            continue;
                        }

                        if (entry.is_directory())
                        {
                            queue.push_back(entry.path().string());
                            continue;
                        }

                        if (entry.is_regular_file())
                        {
                            if (Drill::string_utils::tokenSearch(entry.path().filename().string(),
                                                                 searchValue))
                            {
                                console->info("Found file: `{0}`", entry.path().string());
                                resultsCallback(drill_result_new(entry.path().c_str()));
                            }
                            continue;
                        }

                        console->warn("Unknown file type: `{0}`", entry.path().string());
                    }
                }
                catch (std::exception &e)
                {
                    console->warn(e.what());
                }
            }
        }
    } // namespace crawler

} // namespace Drill