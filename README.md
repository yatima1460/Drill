# Drill 1.0.0rc1

![](https://raw.githubusercontent.com/yatima1460/drill/assets/logo.png)

![](https://raw.githubusercontent.com/yatima1460/drill/D/flowchart.svg)

## TL;DR: What is this

Search files without using indexing, but clever crawling:
- 1 thread per mount point
- Use as much RAM as possible for caching stuff
- Try to avoid "black hole folders" using a regex based blocklist in which the crawler will never come out and never scan useful files (`node_modules`,`Windows`,etc)
- **Intended for desktop users**, no obscure Linux files and system files scans


![](https://raw.githubusercontent.com/yatima1460/drill/assets/screenshot.png)

## How to run this

**Use the provided AppImage, just double click it**

If your distro doesn't ask you to mark it executable or nothing happens try:
- `chmod +x Drill.AppImage`
- `./Drill.AppImage`

## UI Guide
```
Double click    = open
Right click     = open containing folder
Return/Enter    = open
Middle Click    = messagebox with file info (TODO)
```

## Manual prerequisites using Python

- D
- `sudo apt install dub`


### Build and Run
```
dub run
```

## Building AppImage

```
bash build_appimage.sh
```

## What is this

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

## TODO

- FIXME: update list when new results found
- FIXME: remove duplicates if symbolic links make a mess
- FIXME: root folders of threads do not appear in search?
- FIXME: sorting is messy
- FIXME: it seems tkinter misses some double clicks when the mainloop takes too much time
- FIXME: right clicking while hovering a row should select it and open the containing folder


### Usability 

- TODO: AppImage/Snap/Flatpak
- TODO: folders actual size
- TODO: tmp cache index file to speedup boot time
- TODO: metadata searching (mp3, etc...)
- TODO: ESC to close
- TODO: alternate row colors
- TODO: threaded search in index to remove hangs
- TODO: drag and drop (is this even possible with tkinter?)
- TODO: switch to GTK3?
- TODO: memoization
- TODO:  percentage of crawling
- TODO: help in gui (maybe later when more search ways available)

#### Developer

- TODO: NVM could benefit when multiple threads are run for the same disk?
- TODO: statistics to check which are the black hole folders (time crawling inside?)
- TODO: publish to apt
- TODO: remove the print statements and replace them with a log library?
- TODO: cat /proc/mounts for starting the threads
- TODO: cli-version?
- TODO: threadpool?
- TODO: code cleanup: private fields with __ etc
- TODO: add documentation and comments
- TODO: fix the messy imports
- TODO: CASE_INSENSITIVE flag
- TODO: WINDOW_CENTERED flag
- TODO: dump NTFS partition file index?
- TODO: dump ext4 partition file index?