#! py -3

# This software builds all Drill stuff based on the current OS
# The first argument in input is the version number that 
# will be used in the format major.minor

# TODO: name-version-architecture.ext

DMD_VERSION = "2.087.0"


from subprocess import call, check_output
from argparse import ArgumentParser
from os.path import dirname, exists
from shutil import rmtree, copyfile
from os import remove, makedirs
from glob import glob
from sys import platform, argv
import os


import json

with open('dub.json') as json_file:
    data = json.load(json_file)
    DRILL_VERSION = data["version"]


CLI_CONTROL_FILE = '''Package: drill-search-cli
Section: utils
Depends: libgcc1
Priority: optional
Architecture: amd64
Maintainer: Federico Santamorena <federico@santamorena.me>
Homepage: https://github.com/yatima1460/Drill
Source: https://github.com/yatima1460/Drill
Installed-Size: 2048
License: GPL-2
Description: Search files without indexing, but clever crawling
 I was stressed on Linux because I couldn't find the files I needed, file searchers based on system indexing (updatedb) are prone to breaking and hard to configure for the average user, so did an all nighter and started this.
 Drill is a modern file searcher for Linux that tries to fix the old problem of slow searching and indexing. Nowadays even some SSDs are used for storage and every PC has nearly a minimum of 8GB of RAM and quad-core; knowing this it's time to design a future-proof file searcher that doesn't care about weak systems and uses the full multithreaded power in a clever way to find your files in the fastest possible way.
 Heuristics: The first change was the algorithm, a lot of file searchers use depth-first algorithms, this is a very stupid choice and everyone that implemented it is a moron, why? You see, normal humans don't create nested folders too much and you will probably get lost inside "black hole folders" or artificial archives (created by software); a breadth-first algorithm that scans your hard disks by depth has a higher chance to find the files you need. Second change is excluding some obvious folders while crawling like Windows and node_modules, the average user doesn't care about .dlls and all the system files, and generally even devs too don't care, and if you need to find a system file you already know what you are doing and you should not use a UI tool.
 Clever multithreading: The second change is clever multithreading, I've never seen a file searcher that starts a thread per disk and it's 2019. The limitation for file searchers is 99% of the time just the disk speed, not the CPU or RAM, then why everyone just scans the disks sequentially????
 Use your goddamn RAM: The third change is caching everything, I don't care about your RAM, I will use even 8GB of your RAM if this provides me a faster way to find your files, unused RAM is wasted RAM, even truer the more time passes.'''

GTK_CONTROL_FILE = '''Package: drill-search-gtk
Section: utils
Depends: libgtk-3-0 (>= 3.22.0),libgcc1
Priority: optional
Architecture: amd64
Maintainer: Federico Santamorena <federico@santamorena.me>
Homepage: https://github.com/yatima1460/Drill
Source: https://github.com/yatima1460/Drill
Installed-Size: 2048
License: GPL-2
Description: Search files without indexing, but clever crawling
 I was stressed on Linux because I couldn't find the files I needed, file searchers based on system indexing (updatedb) are prone to breaking and hard to configure for the average user, so did an all nighter and started this.
 Drill is a modern file searcher for Linux that tries to fix the old problem of slow searching and indexing. Nowadays even some SSDs are used for storage and every PC has nearly a minimum of 8GB of RAM and quad-core; knowing this it's time to design a future-proof file searcher that doesn't care about weak systems and uses the full multithreaded power in a clever way to find your files in the fastest possible way.
 Heuristics: The first change was the algorithm, a lot of file searchers use depth-first algorithms, this is a very stupid choice and everyone that implemented it is a moron, why? You see, normal humans don't create nested folders too much and you will probably get lost inside "black hole folders" or artificial archives (created by software); a breadth-first algorithm that scans your hard disks by depth has a higher chance to find the files you need. Second change is excluding some obvious folders while crawling like Windows and node_modules, the average user doesn't care about .dlls and all the system files, and generally even devs too don't care, and if you need to find a system file you already know what you are doing and you should not use a UI tool.
 Clever multithreading: The second change is clever multithreading, I've never seen a file searcher that starts a thread per disk and it's 2019. The limitation for file searchers is 99% of the time just the disk speed, not the CPU or RAM, then why everyone just scans the disks sequentially????
 Use your goddamn RAM: The third change is caching everything, I don't care about your RAM, I will use even 8GB of your RAM if this provides me a faster way to find your files, unused RAM is wasted RAM, even truer the more time passes.'''

GTK_DESKTOP_FILE = '''[Desktop Entry]
Name=Drill
Type=Application
Comment=Search files without using indexing, but clever crawling
Icon=drill-search-gtk
Exec=/usr/bin/drill-search-gtk
TryExec=/usr/bin/drill-search-gtk
Terminal=false
Categories=Utility;
Keywords=Search;FileSearch;File Search;Find;Search;
'''

def installD(compiler="dmd"):
    '''
    Installs D and returns dub location
    '''
    if compiler == "gdc":
        NotImplementedError("Drill does not support GDC")

    if platform == "linux" or platform == "linux2":
        # if compiler == "dmd":
        os.system("wget -c http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".linux.tar.xz")
        os.system("7z x -aos dmd."+DMD_VERSION+".linux.tar.xz")
        os.system("7z x -aos dmd."+DMD_VERSION+".linux.tar")
        print("dub/dmd extracted")
        dub = "dmd2/linux/bin64/dub"
        print("dub location is: ", dub)
        os.system("chmod +x "+dub)
        print("dub set as executable")
        os.system("./"+dub+" --version")
        os.system("chmod +x dmd2/linux/bin64/dmd")
        print("dmd set as executable")
        os.system("./"+dub+" --version")
        os.system("./dmd2/linux/bin64/dmd --version")
        return "./"+dub
        # if compiler == "ldc2":
        #     NotImplementedError()
        #     os.system("curl -fsS https://dlang.org/install.sh | bash -s ldc")
        #     os.system("source ~/dlang/ldc-1.16.0/activate")
        #     return "dub"
        
    elif platform == "darwin":
    # OS X
        os.system("wget http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".osx.tar.xz")
        os.system("7z -aoa x dmd."+DMD_VERSION+".osx.tar.xz")
        os.system("7z -aoa x dmd."+DMD_VERSION+".osx.tar")
        dub = "dmd2/osx/bin/dub"
        os.system("chmod +x "+dub)
        os.system("chmod +x \"$PWD\"/dmd2/osx/bin/dmd")
        return dub
    elif platform == "win32":
    # Windows...
        os.system("wget http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".windows.7z")
        os.system("7z x dmd."+DMD_VERSION+".windows.7z")
        cwd = os.getcwd()
        return cwd+"/dmd2/windows/bin/dub.exe"
    else:
        NotImplementedError("Your OS is not supported.")
        

def buildCLI(dub):
    os.system(dub+" build -b release -c CLI --force --verbose")
    print("buildCLI",dub," done")

def buildUI(dub):
    
    if platform == "linux" or platform == "linux2":
        os.system(dub+" build -b release -c GTK --force --verbose")
    elif platform == "darwin":
    # OS X
        NotImplementedError()
    elif platform == "win32":
    # Windows...
        #remember it will end in .exe
        NotImplementedError()
    else:
        NotImplementedError()
    print("buildUI",dub," done")

def createZips():
    '''
    You need to install p7zip-full or p7zip and p7zip-plugins
    '''
    for filename in os.listdir('Build'):
        zip_name = filename+"-"+DRILL_VERSION+".zip"
        os.system("7z a -tzip Output/"+zip_name+" ./Build/"+filename+"/*")
        assert(os.path.exists("Output/"+zip_name))
    print(".zips created")

def packageDeb():

    def packageCLIDeb():
        global CLI_CONTROL_FILE
        DEB_PACKAGE_NAME="drill-search-cli"
        CLI_BUILD_DIR="Drill-CLI-linux-x86_64-release"
        BUILD_DIR="Build/"+CLI_BUILD_DIR
        assert(os.path.exists(BUILD_DIR+"/"+DEB_PACKAGE_NAME))
        

        # install binary redirect for /usr/bin and set it executable
        os.system("mkdir -p DEBFILE/CLI/usr/bin")
        with open("DEBFILE/CLI/usr/bin/"+DEB_PACKAGE_NAME, "w") as text_file:
            text_file.write("#!/bin/bash\n/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME+ "\"\$@\"")
        os.system("chmod +x DEBFILE/CLI/usr/bin/"+DEB_PACKAGE_NAME)
        # install in /opt
        os.system("mkdir -p DEBFILE/CLI/opt/")
        os.system("cp -r "+BUILD_DIR+" DEBFILE/CLI/opt/"+DEB_PACKAGE_NAME)
        os.system("chmod +x DEBFILE/CLI/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME)
        # make .deb metadata
        os.system("mkdir -p DEBFILE/CLI/DEBIAN")
        with open("DEBFILE/CLI/DEBIAN/control", "w") as text_file:
            text_file.write(CLI_CONTROL_FILE+"\nVersion: "+DRILL_VERSION+"\n")
        # build the .deb file
        os.system("dpkg-deb --build DEBFILE/CLI/")
        os.system("mv DEBFILE/CLI.deb Output/Drill-CLI-linux-x86_64-release-"+DRILL_VERSION+".deb")
        assert(os.path.exists("Output/Drill-CLI-linux-x86_64-release-"+DRILL_VERSION+".deb"))
        os.system("sudo dpkg -i Output/Drill-CLI-linux-x86_64-release-"+DRILL_VERSION+".deb")
        print("CLI .deb done")

    def packageGTKDeb():
        global GTK_DESKTOP_FILE
        global GTK_CONTROL_FILE
        DEB_PACKAGE_NAME="drill-search-gtk"
        GTK_BUILD_DIR="Drill-GTK-linux-x86_64-release"
        BUILD_DIR = "Build/"+GTK_BUILD_DIR
        assert(os.path.exists(BUILD_DIR+"/"+DEB_PACKAGE_NAME))
        # install binary redirect for /usr/bin and set it executable
        os.system("mkdir -p DEBFILE/GTK/usr/bin")
        with open("DEBFILE/GTK/usr/bin/"+DEB_PACKAGE_NAME, "w") as text_file:
            text_file.write("#!/bin/bash\n/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME)
        os.system("chmod +x DEBFILE/GTK/usr/bin/"+DEB_PACKAGE_NAME)
        # install in /opt
        os.system("mkdir -p DEBFILE/GTK/opt/")
        os.system("cp -r "+BUILD_DIR+" DEBFILE/GTK/opt/"+DEB_PACKAGE_NAME)
        os.system("chmod +x DEBFILE/GTK/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME)
        # make .deb metadata
        os.system("mkdir -p DEBFILE/GTK/DEBIAN")
        with open("DEBFILE/GTK/DEBIAN/control", "w") as text_file:
            text_file.write(GTK_CONTROL_FILE+"\nVersion: "+DRILL_VERSION+"\n")
        # add desktop file
        os.system("mkdir -p DEBFILE/GTK/usr/share/applications")
        desktop_file = "DEBFILE/GTK/usr/share/applications/drill-search-gtk.desktop"
        with open(desktop_file, "w") as text_file:
            text_file.write(GTK_DESKTOP_FILE)
        os.system("desktop-file-validate "+desktop_file)
        # add icon
        os.system("mkdir -p DEBFILE/GTK/usr/share/pixmaps")
        os.system("cp Assets/icon.svg DEBFILE/GTK/usr/share/pixmaps/drill-search-gtk.svg")
        # build the .deb file
        os.system("dpkg-deb --build DEBFILE/GTK/")
        os.system("mv DEBFILE/GTK.deb Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".deb")
        assert(os.path.exists("Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".deb"))
        os.system("sudo dpkg -i Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".deb")
        print("GTK .deb done")

    packageCLIDeb()
    packageGTKDeb()


def packageAppImage():
    global GTK_DESKTOP_FILE
    os.system("wget -c https://raw.githubusercontent.com/probonopd/AppImages/master/pkg2appimage")

    appimage_dir = "Drill"
    os.system("mkdir -p "+appimage_dir+"/usr")

    # create desktop file
    desktop_file = appimage_dir+"/drill-search-gtk.desktop"
    with open(desktop_file, "w") as text_file:
        text_file.write(GTK_DESKTOP_FILE)
    os.system("desktop-file-validate "+desktop_file)
    print("AppImage .desktop created.")

    with open(appimage_dir+"/drill-search-gtk.bash", "w") as text_file:
        text_file.write("#!/bin/bash\n./drill-search-gtk.elf")

    # add icon
    os.system("cp Assets/icon.svg "+appimage_dir+"/drill-search-gtk.svg")
    print("AppImage icon copied.")

    # copy files
    # os.system("cp -r Build/Drill-GTK-linux-x86_64-release/* "+appimage_dir)
    # os.system("chmod +x "+appimage_dir+"/drill-search-gtk")
    # print("AppImage files copied.")
    
    #create appimage
    APP_IMAGE_SCRIPT = '''
app: Drill
script: 
 - echo
 - mv ../drill-search-gtk.desktop .
 - mv ../drill-search-gtk.svg .
 - cp -r ../../Build/Drill-GTK-linux-x86_64-release/* usr/bin
'''
#  - mv ../drill-search-gtk ./usr/drill-search-gtk
#  - mv ../drill-search-gtk.bash ./usr/bin/drill-search-gtk
    with open("APP_IMAGE_SCRIPT.yml", "w") as text_file:
            text_file.write(APP_IMAGE_SCRIPT)
    os.system("bash -ex ./pkg2appimage APP_IMAGE_SCRIPT.yml")
    os.system("mv out/*.AppImage Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".AppImage")
    assert(os.path.exists("Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".AppImage"))
    print("AppImage done.")

def packagePortables():
    if platform == "linux" or platform == "linux2":
        packageAppImage()

def packageInstallers():
    if platform == "linux" or platform == "linux2":
        packageDeb()

if __name__ == "__main__":
    dub = installD()
    buildCLI(dub)
    buildUI(dub)
    createZips()
    packagePortables()
    packageInstallers()
    print("All builds done.")
        

    

