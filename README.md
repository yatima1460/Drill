# Drill

|Project|Linux|Windows|MacOS|
|-------|-----|-------|-----|
| Core | [![Actions Status](https://github.com/yatima1460/Drill/workflows/Linux_Core/badge.svg)](https://github.com/yatima1460/Drill/actions) | [![Actions Status](https://github.com/yatima1460/Drill/workflows/Windows_Core/badge.svg)](https://github.com/yatima1460/Drill/actions) | [![Actions Status](https://github.com/yatima1460/Drill/workflows/MacOS_Core/badge.svg)](https://github.com/yatima1460/Drill/actions)|
| Core Test | [![Actions Status](https://github.com/yatima1460/Drill/workflows/TestLinux/badge.svg)](https://github.com/yatima1460/Drill/actions) |[![Actions Status](https://github.com/yatima1460/Drill/workflows/TestWindows/badge.svg)](https://github.com/yatima1460/Drill/actions) | [![Actions Status](https://github.com/yatima1460/Drill/workflows/TestMacOS/badge.svg)](https://github.com/yatima1460/Drill/actions)|
| CLI | [![Actions Status](https://github.com/yatima1460/Drill/workflows/Linux_CLI/badge.svg)](https://github.com/yatima1460/Drill/actions) | [![Actions Status](https://github.com/yatima1460/Drill/workflows/Windows_CLI/badge.svg)](https://github.com/yatima1460/Drill/actions) | [![Actions Status](https://github.com/yatima1460/Drill/workflows/MacOS_CLI/badge.svg)](https://github.com/yatima1460/Drill/actions) |
| Qt | [![Actions Status](https://github.com/yatima1460/Drill/workflows/Linux_Qt/badge.svg)](https://github.com/yatima1460/Drill/actions) |[![Actions Status](https://github.com/yatima1460/Drill/workflows/Windows_Qt/badge.svg)](https://github.com/yatima1460/Drill/actions) | [![Actions Status](https://github.com/yatima1460/Drill/workflows/MacOS_Qt/badge.svg)](https://github.com/yatima1460/Drill/actions) |

[![Financial Contributors on Open Collective](https://opencollective.com/Drill/all/badge.svg?label=financial+contributors)](https://opencollective.com/Drill) [![GitHub issues](https://img.shields.io/github/issues/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/issues)
[![GitHub forks](https://img.shields.io/github/forks/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/network)
[![GitHub stars](https://img.shields.io/github/stars/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/stargazers)
[![GitHub license](https://img.shields.io/github/license/yatima1460/Drill.svg)](https://github.com/yatima1460/Drill/blob/master/LICENSE)

[![Twitter](https://img.shields.io/twitter/url/https/github.com/yatima1460/Drill.svg?style=social)](https://twitter.com/intent/tweet?text=Wow:&url=https%3A%2F%2Fgithub.com%2Fyatima1460%2FDrill)

Get notified for latest releases
[![Telegram](https://raw.githubusercontent.com/yatima1460/Drill/gh-pages/icons/telegram_icon.png)](https://telegram.me/drill_search)

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

If you want a version that doesn't require sudo or FUSE download the .zip files.

# Build and Run

`git clone https://github.com/yatima1460/Drill.git`
`git submodule update --init --recursive`


## UI

TODO

## CLI

`cd CLI && cmake . && make -j8`

etc..

## Build prerequisites

### Linux

```
sudo apt-get update
sudo apt-get install build-essential cmake
```

### OSX

DO A PULL REQUEST TO FILL THIS EMPTY SECTION

### Windows

DO A PULL REQUEST TO FILL THIS EMPTY SECTION


### Debugging

I used more C but I don't think it should be the case with C++, but remember that with C and `calloc` + GDB what happens is that GDB overwrites the `calloc` function and produces a non zero filled buffer for debugging purposes(???), so don't trust `calloc` when debugging with GDB if you will ever use it.

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
Don't make me swear like Linus Torvalds

# TODOs

- Backend
    - settings in .config/drill-search
    - Commas in numbers strings
        - Correct separator based on current system internationalization
    - AM/PM time base
    - 1 Threadpool per mount point
        - 1 Threadpool PER DISK if possible
        - NVM could benefit when multiple threads are run for the same disk?
    - Metadata searching and new tokens (mp3, etc...)
    - No GC in Backend

- ncurses?

- UI
    - Open containing folder with right click 
    - Alternate row colors
    - Error messagebox if opening file fails
    - .rpm
    - Snap
    - Flatpak
    - Drag and drop?

- CLI


## Contributors

### Code Contributors

This project exists thanks to all the people who contribute. [[Contribute](CONTRIBUTING.md)].
<a href="https://github.com/yatima1460/Drill/graphs/contributors"><img src="https://opencollective.com/Drill/contributors.svg?width=890&button=false" /></a>

### Financial Contributors

Become a financial contributor and help us sustain our community. [[Contribute](https://opencollective.com/Drill/contribute)]

#### Individuals

<a href="https://opencollective.com/Drill"><img src="https://opencollective.com/Drill/individuals.svg?width=890"></a>

#### Organizations

Support this project with your organization. Your logo will show up here with a link to your website. [[Contribute](https://opencollective.com/Drill/contribute)]

<a href="https://opencollective.com/Drill/organization/0/website"><img src="https://opencollective.com/Drill/organization/0/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/1/website"><img src="https://opencollective.com/Drill/organization/1/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/2/website"><img src="https://opencollective.com/Drill/organization/2/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/3/website"><img src="https://opencollective.com/Drill/organization/3/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/4/website"><img src="https://opencollective.com/Drill/organization/4/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/5/website"><img src="https://opencollective.com/Drill/organization/5/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/6/website"><img src="https://opencollective.com/Drill/organization/6/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/7/website"><img src="https://opencollective.com/Drill/organization/7/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/8/website"><img src="https://opencollective.com/Drill/organization/8/avatar.svg"></a>
<a href="https://opencollective.com/Drill/organization/9/website"><img src="https://opencollective.com/Drill/organization/9/avatar.svg"></a>
