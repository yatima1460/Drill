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

import sys

import json

with open('dub.json') as json_file:
    data = json.load(json_file)
    DRILL_VERSION = data["version"]

SOURCE_URL = "https://github.com/yatima1460/Drill/archive/"+DRILL_VERSION+".tar.gz"


RPM_SPEC_FILE = '''
Name:       drill-search-cli
Version:    1
Release:    1
Summary:    Search files without indexing, but clever crawling
License:    GPL-2
Source:     drill-search-cli

%description
I was stressed on Linux because I couldn't find the files I needed, file searchers based on system indexing (updatedb) are prone to breaking and hard to configure for the average user, so did an all nighter and started this.
Drill is a modern file searcher for Linux that tries to fix the old problem of slow searching and indexing. Nowadays even some SSDs are used for storage and every PC has nearly a minimum of 8GB of RAM and quad-core; knowing this it's time to design a future-proof file searcher that doesn't care about weak systems and uses the full multithreaded power in a clever way to find your files in the fastest possible way.
Heuristics: The first change was the algorithm, a lot of file searchers use depth-first algorithms, this is a very stupid choice and everyone that implemented it is a moron, why? You see, normal humans don't create nested folders too much and you will probably get lost inside "black hole folders" or artificial archives (created by software); a breadth-first algorithm that scans your hard disks by depth has a higher chance to find the files you need. Second change is excluding some obvious folders while crawling like Windows and node_modules, the average user doesn't care about .dlls and all the system files, and generally even devs too don't care, and if you need to find a system file you already know what you are doing and you should not use a UI tool.
Clever multithreading: The second change is clever multithreading, I've never seen a file searcher that starts a thread per disk and it's 2019. The limitation for file searchers is 99% of the time just the disk speed, not the CPU or RAM, then why everyone just scans the disks sequentially????
Use your goddamn RAM: The third change is caching everything, I don't care about your RAM, I will use even 8GB of your RAM if this provides me a faster way to find your files, unused RAM is wasted RAM, even truer the more time passes.

%prep
%setup -q

%source


%build
dub -b build

%install
# install -m 755 drill-search-cli %{buildroot}/drill-search-cli

%files
/Build/Drill-CLI-linux-x86_64-release/drill-search-cli
'''


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
Depends: libgtk-3-0 (>= 3.16.0),libgcc1
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

def shell(string):
    
    exit_code = os.system(string)
    #print("\n[.travis.py] "+string)
    if exit_code != 0:
        sys.stderr.write("\nERROR: Command '"+string+"' exited with code "+str(exit_code)+"\n")
        exit(exit_code)

def installD(compiler="dmd"):
    '''
    Installs D and returns dub location
    '''
    if compiler == "gdc":
        NotImplementedError("Drill does not support GDC")

    if platform == "linux" or platform == "linux2":
        # if compiler == "dmd":
        shell("wget -c http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".linux.tar.xz")
        shell("7z x -aos dmd."+DMD_VERSION+".linux.tar.xz")
        shell("7z x -aos dmd."+DMD_VERSION+".linux.tar")
        print("dub/dmd extracted")
        dub = "dmd2/linux/bin64/dub"
        print("dub location is: ", dub)
        shell("chmod +x "+dub)
        print("dub set as executable")
        shell("./"+dub+" --version")
        shell("chmod +x dmd2/linux/bin64/dmd")
        print("dmd set as executable")
        shell("./"+dub+" --version")
        shell("./dmd2/linux/bin64/dmd --version")
        return "./"+dub
        # if compiler == "ldc2":
        #     NotImplementedError()
        #     shell("curl -fsS https://dlang.org/install.sh | bash -s ldc")
        #     shell("source ~/dlang/ldc-1.16.0/activate")
        #     return "dub"
        
    elif platform == "darwin":
    # OS X
        shell("wget http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".osx.tar.xz")
        shell("7z -aoa x dmd."+DMD_VERSION+".osx.tar.xz")
        shell("7z -aoa x dmd."+DMD_VERSION+".osx.tar")
        dub = "dmd2/osx/bin/dub"
        shell("chmod +x "+dub)
        shell("chmod +x \"$PWD\"/dmd2/osx/bin/dmd")
        return dub
    elif platform == "win32":
    # Windows...
        shell("wget http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".windows.7z")
        shell("7z x dmd."+DMD_VERSION+".windows.7z")
        cwd = os.getcwd()
        return cwd+"/dmd2/windows/bin/dub.exe"
    else:
        NotImplementedError("Your OS is not supported.")
        

def buildCLI(dub):
    shell(dub+" build -b release -c CLI --force --verbose")
    print("buildCLI",dub," done")

def buildUI(dub):
    
    if platform == "linux" or platform == "linux2":
        shell(dub+" build -b release -c GTK --force --verbose")
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
        shell("7z a -tzip Output/"+zip_name+" ./Build/"+filename+"/*")
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
        shell("mkdir -p DEBFILE/CLI/usr/bin")
        with open("DEBFILE/CLI/usr/bin/"+DEB_PACKAGE_NAME, "w") as text_file:
            text_file.write("#!/bin/bash\n/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME+ " \"$@\"")
        shell("chmod +x DEBFILE/CLI/usr/bin/"+DEB_PACKAGE_NAME)
        # install in /opt
        shell("mkdir -p DEBFILE/CLI/opt/")
        shell("cp -r "+BUILD_DIR+" DEBFILE/CLI/opt/"+DEB_PACKAGE_NAME)
        shell("chmod +x DEBFILE/CLI/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME)
        # make .deb metadata
        shell("mkdir -p DEBFILE/CLI/DEBIAN")
        with open("DEBFILE/CLI/DEBIAN/control", "w") as text_file:
            text_file.write(CLI_CONTROL_FILE+"\nVersion: "+DRILL_VERSION+"\n")
        # build the .deb file
        shell("dpkg-deb --build DEBFILE/CLI/")
        shell("mv DEBFILE/CLI.deb Output/Drill-CLI-linux-x86_64-release-"+DRILL_VERSION+".deb")
        assert(os.path.exists("Output/Drill-CLI-linux-x86_64-release-"+DRILL_VERSION+".deb"))
        if 'TRAVIS_OS_NAME' in os.environ:
            print("Travis OS detected, trying to install the CLI .deb")
            shell("sudo dpkg -i Output/Drill-CLI-linux-x86_64-release-"+DRILL_VERSION+".deb")
        print("CLI .deb done")
        shell("rm -rf DEBFILE/CLI")
        print("CLI .deb cleanup")

    def packageGTKDeb():
        global GTK_DESKTOP_FILE
        global GTK_CONTROL_FILE
        DEB_PACKAGE_NAME="drill-search-gtk"
        GTK_BUILD_DIR="Drill-GTK-linux-x86_64-release"
        BUILD_DIR = "Build/"+GTK_BUILD_DIR
        assert(os.path.exists(BUILD_DIR+"/"+DEB_PACKAGE_NAME))
        # install binary redirect for /usr/bin and set it executable
        shell("mkdir -p DEBFILE/GTK/usr/bin")
        with open("DEBFILE/GTK/usr/bin/"+DEB_PACKAGE_NAME, "w") as text_file:
            text_file.write("#!/bin/bash\n/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME)
        shell("chmod +x DEBFILE/GTK/usr/bin/"+DEB_PACKAGE_NAME)
        # copy all files and install in /opt
        shell("mkdir -p DEBFILE/GTK/opt/")
        shell("cp -r "+BUILD_DIR+"/ DEBFILE/GTK/opt/"+DEB_PACKAGE_NAME)
        shell("chmod +x DEBFILE/GTK/opt/"+DEB_PACKAGE_NAME+"/"+DEB_PACKAGE_NAME)
        # make .deb metadata
        shell("mkdir -p DEBFILE/GTK/DEBIAN")
        with open("DEBFILE/GTK/DEBIAN/control", "w") as text_file:
            text_file.write(GTK_CONTROL_FILE+"\nVersion: "+DRILL_VERSION+"\n")
        # add desktop file
        shell("mkdir -p DEBFILE/GTK/usr/share/applications")
        desktop_file = "DEBFILE/GTK/usr/share/applications/drill-search-gtk.desktop"
        with open(desktop_file, "w") as text_file:
            text_file.write(GTK_DESKTOP_FILE)
        shell("desktop-file-validate "+desktop_file)
        # add icon
        shell("mkdir -p DEBFILE/GTK/usr/share/pixmaps")
        shell("cp Assets/icon.svg DEBFILE/GTK/usr/share/pixmaps/drill-search-gtk.svg")
        # build the .deb file
        shell("dpkg-deb --build DEBFILE/GTK/")
        shell("mv DEBFILE/GTK.deb Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".deb")
        assert(os.path.exists("Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".deb"))
        if 'TRAVIS_OS_NAME' in os.environ:
            print("Travis OS detected, trying to install the GTK .deb")
            shell("sudo dpkg -i Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".deb")
        print("GTK .deb done")
        shell("rm -rf DEBFILE/GTK")
        print("GTK .deb cleanup")

    packageCLIDeb()
    packageGTKDeb()


def packageAppImage():
    global GTK_DESKTOP_FILE
    shell("wget -c https://raw.githubusercontent.com/probonopd/AppImages/master/pkg2appimage")

    appimage_dir = "Drill"
    shell("mkdir -p "+appimage_dir+"/usr")

    # create desktop file
    desktop_file = appimage_dir+"/drill-search-gtk.desktop"
    with open(desktop_file, "w") as text_file:
        text_file.write(GTK_DESKTOP_FILE)
    shell("desktop-file-validate "+desktop_file)
    print("AppImage .desktop created.")

    with open(appimage_dir+"/drill-search-gtk.bash", "w") as text_file:
        text_file.write("#!/bin/bash\n./drill-search-gtk.elf")

    # add icon
    shell("cp Assets/icon.svg "+appimage_dir+"/drill-search-gtk.svg")
    print("AppImage icon copied.")

    # copy files
    # shell("cp -r Build/Drill-GTK-linux-x86_64-release/* "+appimage_dir)
    # shell("chmod +x "+appimage_dir+"/drill-search-gtk")
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
    shell("bash -ex ./pkg2appimage APP_IMAGE_SCRIPT.yml")
    shell("mv out/*.AppImage Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".AppImage")
    assert(os.path.exists("Output/Drill-GTK-linux-x86_64-release-"+DRILL_VERSION+".AppImage"))
    print("AppImage done.")
    shell("rm -rf Drill")
    shell("rmdir out")
    shell("rm pkg2appimage")
    shell("rm APP_IMAGE_SCRIPT.yml")
    print("AppImage cleanup")

def packagePortables():
    if platform == "linux" or platform == "linux2":
        packageAppImage()

def packageRpm():
    with open("drill-search-gtk.spec", "w") as text_file:
        text_file.write(RPM_SPEC_FILE)
    shell("rpmbuild -ba drill-search-gtk.spec")


def packageSnap():
    shell("sudo snap install --classic snapcraft")
    shell("mkdir -p mysnaps/drill-search-gtk/snap")
    os.chdir("mysnaps")
    shell("snapcraft init")
    SNAP_FILE = '''name: drill-search-gtk # you probably want to 'snapcraft register <name>'
version: '0.1' # just for humans, typically '1.2+git' or '1.3.2'
summary: Single-line elevator pitch for your amazing snap # 79 char long summary
description: |
  This is my-snap's description. You have a paragraph or two to tell the
  most important story about your snap. Keep it under 100 words though,
  we live in tweetspace and your description wants to look good in the snap
  store.

grade: devel # must be 'stable' to release into 'candidate' and 'stable' channels
confinement: devmode # use 'strict' once you have the right plugs and slots
parts:
  gtk:
    source: '''+SOURCE_URL+'''
    plugin: autotools
'''

    shell("snapcraft")


    os.chdir("../")



def packageInstallers():
    if platform == "linux" or platform == "linux2":
        packageDeb()
        # packageRpm()
        # packageSnap()

if __name__ == "__main__":
    if len(argv) == 1:
        dub = installD()
        buildCLI(dub)
        buildUI(dub)
        createZips()
        packagePortables()
        packageInstallers()
        print("All builds done.")
    # useful args for local testing
    if len(argv) == 2:
        if argv[1] == "appimage":
            dub = installD()
            buildUI(dub)
            packageAppImage()
            exit(0)
        if argv[1] == "deb":
            dub = installD()
            buildCLI(dub)
            buildUI(dub)
            packageDeb()
            exit(0)
        if argv[1] == "snap":
            exit(1)
    if platform == "linux" or platform == "linux2":
        shell("rm dmd."+DMD_VERSION+".linux.tar")
        shell("rm dmd."+DMD_VERSION+".linux.tar.xz")
    if platform == "darwin":
        # TODO: add OSX cleanup
        pass
    if platform == "windows":
        # TODO: add Windows cleanup
        pass
    shell("rm -rf dmd2")
    print("dmd cleanup done.")

        

    

