
#include "Crawler.hpp"
#include "RegexUtils.hpp"

#include <filesystem>
#include <assert.h>

namespace Drill
{

Crawler::Crawler(const std::string mountpoint, const DrillConfig cfg,const std::vector<std::string> mountpoints) : mountpoint(mountpoint), mountpoints(mountpoints)
{
    assert(!mountpoint.empty());
    //assert(cfg != nullptr);

    log = spdlog::stdout_color_st(mountpoint);
    log->set_level(spdlog::level::info);
    log->debug("Crawler `{0}` created on the main thread", mountpoint);

    this->crawlerConfigs = cfg;
}

void Crawler::run()
{
    assert(!mountpoint.empty());
    //assert(cfg != nullptr);

    log->info("Crawler `{0}` running as thread", mountpoint);



    // Use the queue as a stack to scan using a breadth-first algorithm
    std::vector<std::string> queue;

    /*
    Every Crawler will have all the other mountpoints in its blocklist
    In this way crawlers will not cross paths in the worst case scenario
    of mount shenanigans
    */
    for (const auto mnt : mountpoints)
    {
        if (mnt != mountpoint)
        {
            const std::string mountpointRegexStr = "^"+mnt+"$";
            crawlerConfigs.blocklistsRegex.push_back(std::regex(mountpointRegexStr));
            log->info("added `{0}` to blocklists", mountpointRegexStr);
        }
        else
        {
            log->debug("`{0}` skipped adding to blocklists, it's the crawler mountpoint", mnt);
        }
        
            
    }

    queue.push_back(mountpoint);
    log->debug("`{0}` mountpoint added to queue", mountpoint);

    while (!queue.empty())
    {
        auto directory = queue.back();
        queue.pop_back();



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

        /*
        We get a list of the shallow files inside
        NOT RECURSIVELY, JUST THE FILES IMMEDIATELY INSIDE
        If we fail to get the files we just stop this directory scanning
        */

        try
        {

            for (const auto &entry : std::filesystem::directory_iterator(directory))
            {
                assert(entry.is_directory());

                if (entry.is_symlink() ||
                    entry.is_block_file() ||
                    entry.is_character_file() ||
                    entry.is_fifo() ||
                    entry.is_socket() ||
                    entry.is_other())
                {
                    log->trace("Special symlink/block/character/fifo/socket/other file ignored: `{0}`", entry.path().c_str());
                    continue;
                }

                //const auto filePath = entry.path();

                if (entry.is_directory())
                {
                    if (isInRegexList(crawlerConfigs.blocklistsRegex, entry.path().c_str()))
                    {
                        log->trace("Skipping directory `{0}` because in blocklists", entry.path().c_str());
                        continue;
                    }

                    //TODO: insert front if priority
                    // if (isInRegexList(cfg->priorityListsRegex, entry.path().c_str()))
                    // {
                    //     queue.insert(queue.begin(), entry.path().c_str());
                    // }
                    // else
                    // {
                    queue.push_back(entry.path().c_str());
                    log->trace("Directory `{0}` added to queue, not in blocklists", entry.path().c_str());

                    // }
                }

                const FileInfo fi(entry);


                // TODO: add matching functions like `content:`, error if null
                if (std::string(entry.path().filename().c_str()).find("1080p") != std::string::npos)
                {
                    log->info(fi.path);
                }
            }
        }
        catch (std::filesystem::__cxx11::filesystem_error &e)
        {
            log->warn(e.what());
        }
    }

    log->info("Finished crawling mountpoint `{0}`, exiting thread", mountpoint);
}

} // namespace Drill