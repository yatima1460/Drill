# Drill

![](https://repository-images.githubusercontent.com/184500340/186b3200-75cb-11e9-9f5b-6dd249573076)

[![Build Status](https://travis-ci.org/yatima1460/Drill.svg?branch=master)](https://travis-ci.org/yatima1460/Drill)
[![GitHub issues](https://img.shields.io/github/issues/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/issues)
[![GitHub forks](https://img.shields.io/github/forks/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/network)
[![GitHub stars](https://img.shields.io/github/stars/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/stargazers)
[![GitHub license](https://img.shields.io/github/license/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/blob/master/LICENSE)

[![Twitter](https://img.shields.io/twitter/url/https/github.com/yatima1460/Drill.svg?style=social)](https://twitter.com/intent/tweet?text=Wow:&url=https%3A%2F%2Fgithub.com%2Fyatima1460%2FDrill)

# TL;DR: What is this

Search files without indexing, but clever crawling:
- At least 1 thread per mount point
- Use as much RAM as possible for caching stuff
- Try to avoid "black hole folders" using a regex based blocklist in which the crawler will never come out and never scan useful files (`node_modules`,`Windows`,etc)
- **Intended for desktop users**, no obscure Linux files and system files scans
- Use priority lists to first scan important folders.
- Betting on the future: slowly being optimized for SSDs/M.2 or fast RAID arrays


![](https://raw.githubusercontent.com/yatima1460/Drill/gh-pages/screenshot.png)

# How to run this

**Install the provided .deb (sudo required) or just double click the AppImage (no sudo)**

If your distro doesn't ask you to mark the AppImage as executable or nothing happens try:
- `chmod +x appimage_name_you_downloaded.AppImage`
- `./appimage_name_you_downloaded.AppImage`

If you want a version that doesn't require sudo and can be configurable download the .zip files.

# UI Guide

- Open                    = Left Double Click / Return / Enter / Space
- ~~Open containing folder  = Contextual menu~~



# Build and Run

**Some dependencies don't build with GDC!!!**
**Use DMD or LDC!!!**


## Build

### Windows

- Install DMD
- Install Visual Studio 2017
- Install VisualD
- Open the project & Build Solution

### Linux and OSX

- Install dmd and dub
- `bash build_linux.bash`

### Remember

If you omit `-b release` a debug version (not recommended) will be created

### Linux
- `git clone https://github.com/yatima1460/Drill.git`
- D
    - `curl -fsS https://dlang.org/install.sh | bash -s dmd`
    - `. ~/dlang/dmd-2.086.0/activate`
- `cd source/ui` or `cd source/cli`
- `dub build -b release`
- `cd ../../` location of the binary

### Windows

TODO

### OSX

TODO

# What is this

I was stressed on Linux because I couldn't find the files I needed, file searchers based on system indexing (updatedb) are prone to breaking and hard to configure for the average user, so did an all nighter and started this.

Drill is a modern file searcher for Linux that tries to fix the old problem of slow searching and indexing.
Nowadays even some SSDs are used for storage and every PC has nearly a minimum of 8GB of RAM and quad-core;
knowing this it's time to design a future-proof file searcher that doesn't care about weak systems and uses the full multithreaded power in a clever way to find your files in the fastest possible way.

* Heuristics:
The first change was the algorithm, a lot of file searchers use depth-first algorithms, this is a very stupid choice and everyone that implemented it is a moron, why? 
You see, normal humans don't create nested folders too much and you will probably get lost inside "black hole folders" or artificial archives (created by software); a breadth-first algorithm that scans your hard disks by depth has a higher chance to find the files you need.
Second change is excluding some obvious folders while crawling like `Windows` and `node_modules`, the average user doesn't care about .dlls and all the system files, and generally even devs too don't care, and if you need to find a system file you already know what you are doing and you should not use a UI tool.

* Clever multithreading: The second change is clever multithreading, I've never seen a file searcher that starts a thread *per disk* and it's 2019. The limitation for file searchers is 99% of the time just the disk speed, not the CPU or RAM, then why everyone just scans the disks sequentially????

* Use your goddamn RAM: The third change is caching everything, I don't care about your RAM, I will use even 8GB of your RAM if this provides me a faster way to find your files, unused RAM is wasted RAM, even truer the more time passes.

# Contributing
Read the Issues and check the labels for high priority ones


TODOs will slowly get converted to Issues
- Core Backend
    - Open file or path
        - ~~Linux X11~~
            - ~~Open File~~
            - Select file if contained folder
            - Error on file open
        - Linux Wayland
            - Open File
            - Select file if contained folder
            - Error on file open
        - Windows
            - Open File
            - Select file if contained folder
            - Error on file open
        - MacOS
            - ~~Open File~~
            - Select file if contained folder
            - Error on file open
    - ~~All comparisons need to be done in lower case strings~~
    - ~~Priority lists specified in assets/prioritylists~~
    - ~~Multi-token search (searching "a b" will find all files with "a" and "b" in the name)~~
    - /home/username needs to have higher priority over / crawler when /home isn't mounted on a secondary mountpoint
    - Sorting by column
    - Commas in numbers strings
        - Correct separator based on current system internationalization
    - AM/PM time base
        - Linux
        - Windows
        - MacOS
    - Folders actual size
    - Icons image needs to be generic and in the backend
    - 1 Threadpool per mount point
        - 1 Threadpool PER DISK if possible
    - Metadata searching and new tokens (mp3, etc...)
    - Memoization/Cache
    - Percentage of crawling
    - About dialog in GUI
    - Remove the synchronizations using a concurrency list
    - ~~Split Drill in DrillGTK and DrillCore~~
    - Add documentation and comments
    - Fix messy imports
    - ~~Logging in debug mode~~
    - NVM could benefit when multiple threads are run for the same disk?
    - No GC

- Cli Frontend
    - More arguments
    - ~~Better/bare printing~~

- ncurses

- GTK Frontend
    - ~~Open file with double click~~
    - ~~Add to UI list when new results found~~
    - ~~AppImage~~
    - Open containing folder with right click 
    - Alternate row colors
    - ESC to close
    - Error messagebox if opening file fails
    - ~~Icons near the file name~~
    - ~~.deb~~
    - .rpm
    - Snap
    - Flatpak
    - Drag and drop

- Windows
    - Open file with double click
    - Add to UI list when new results found
    - Portable .exe
        - Installer
    - Open containing folder with right click 
    - Alternate row colors
    - ESC to close
    - Error messagebox if opening file fails
    - Icons near the file name
    - Drag and drop

- MacOS
    - Open file with double click
    - Add to UI list when new results found
    - Portable executable
        - Installer
    - Open containing folder with right click 
    - Alternate row colors
    - ESC to close
    - Error messagebox if opening file fails
    - Icons near the file name
    - Drag and drop
