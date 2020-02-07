#! py -3

###################################################
#
# Just run `python build.py`
# 
#
# appimage only: `python build.py appimage`
# deb only: `python build.py deb`
#
###################################################
# BUILD VARIABLES
###################################################


ARCHITECTURE = "x86_64"

OUTPUT_FOLDER = "Output"

# When built locally and not on Travis what number to use
# Remember: .deb files like only numeric values
LOCAL_VERSION_NUMBER = "0"

# DUB local command
dub = "dub"

# DMD + DUB version to download if not found locally
COMPILER = "dmd"
DMD_VERSION = "2.090.0"

DRILL_DESCRIPTION = "Search files without indexing, but clever crawling"

DEB_CONTROL_FILE = '''Section: utils
Priority: optional
Architecture: amd64
Maintainer: Federico Santamorena <federico@santamorena.me>
Homepage: https://github.com/yatima1460/Drill
Source: https://github.com/yatima1460/Drill
Installed-Size: 2048
License: GPL-2
Description: '''+DRILL_DESCRIPTION




#######
# CLI #
#######

FILENAME_CLI_PRE_NAME = "DrillCLI"

DEB_CLI_PACKAGE_NAME = "drill-search-cli"
DEB_CLI_DEPENDENCIES = "libgcc1"

#######
# GTK #
#######

FILENAME_GTK_PRE_NAME = "Drill"

DEB_GTK_PACKAGE_NAME = "drill-search-gtk"
DEB_GTK_DEPENDENCIES = "libgtk-3-0 (>= 3.22.30),libgcc1"

GTK_DESKTOP_FILE = '''[Desktop Entry]
Name=Drill
Type=Application
Comment='''+DRILL_DESCRIPTION+'''
Icon=drill-search-gtk
Exec=/usr/bin/drill-search-gtk
TryExec=/usr/bin/drill-search-gtk
Terminal=false
Categories=Utility;
Keywords=Search;FileSearch;File Search;Find;Search;
'''



###################################################
###################################################
###################################################

from subprocess import call, check_output
from argparse import ArgumentParser
from os.path import dirname, exists
from shutil import rmtree, copyfile
from os import remove, makedirs
from glob import glob
from sys import platform, argv
from distutils.spawn import find_executable
import os
import sys

def shell(string):
    '''
    Wrapper around os.system to execute shell commands
    Terminates this script instantly with a message if a shell command fails
    '''
    exit_code = os.system(string)
    #print("\n[.travis.py] "+string)
    if exit_code != 0:
        sys.stderr.write("\nERROR: Command '"+string+"' exited with code "+str(exit_code)+"\n")
        exit(exit_code)


def installD():
    '''
    Installs D and returns dub location
    '''
    if COMPILER == "gdc":
        NotImplementedError("Drill does not support compiling with GDC")
    if COMPILER == "ldc":
        NotImplementedError("Drill does not support downloading LDC")

    # Linux
    if platform == "linux" or platform == "linux2":
        shell("wget -c http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".linux.tar.xz")
        shell("7z x -aos dmd."+DMD_VERSION+".linux.tar.xz")
        shell("7z x -aos dmd."+DMD_VERSION+".linux.tar")
        dub = "dmd2/linux/bin64/dub"
        shell("chmod +x "+dub)
        shell("./"+dub+" --version")
        shell("chmod +x dmd2/linux/bin64/dmd")
        shell("./"+dub+" --version")
        shell("./dmd2/linux/bin64/dmd --version")
        return "./"+dub

    # OS X
    elif platform == "darwin":
        shell("wget http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".osx.tar.xz")
        shell("7z -aoa x dmd."+DMD_VERSION+".osx.tar.xz")
        shell("7z -aoa x dmd."+DMD_VERSION+".osx.tar")
        dub = "dmd2/osx/bin/dub"
        shell("chmod +x "+dub)
        shell("chmod +x \"$PWD\"/dmd2/osx/bin/dmd")
        return dub
        
    # Windows
    # Remember the executable will end in .exe
    elif platform == "win32":

        shell("wget http://downloads.dlang.org/releases/2.x/"+DMD_VERSION+"/dmd."+DMD_VERSION+".windows.7z")
        shell("7z x dmd."+DMD_VERSION+".windows.7z")
        cwd = os.getcwd()
        return cwd+"/dmd2/windows/bin/dub.exe"
    else:
        NotImplementedError("Your OS is not supported.")
   

def buildCLI(dub):
    '''
    Builds the CLI version of Drill
    '''
    shell(dub+" build -b release -c CLI --force --parallel --verbose --arch="+ARCHITECTURE)
    print("buildCLI",dub," done")

def buildUI(dub):
    '''
    Builds the UI version of Drill
    '''
    # Linux
    if platform == "linux" or platform == "linux2":
        shell(dub+" build -b release -c GTK --force --parallel --verbose --arch="+ARCHITECTURE)
    # OS X
    elif platform == "darwin":
        NotImplementedError()
    # Windows
    # Remember the executable will end in .exe
    elif platform == "win32":
        
        NotImplementedError()
    else:
        NotImplementedError()
    print("buildUI",dub," done")

def createZips():
    '''
    You need to install p7zip-full or p7zip and p7zip-plugins
    '''
    if platform == "linux" or platform == "linux2":
        OS_NAME = "linux"
    elif platform == "darwin": 
        OS_NAME = "osx"
    elif platform == "win32":
        OS_NAME = "windows"
    else:
        OS_NAME = "OS_NOT_SUPPORTED"
    shell("7z a -tzip Output/"+FILENAME_GTK_PRE_NAME+"-v"+DRILL_VERSION+"-"+ARCHITECTURE+"-"+OS_NAME+".zip ./Build/Drill-GTK-"+OS_NAME+"-x86_64-release/*")
    shell("7z a -tzip Output/"+FILENAME_CLI_PRE_NAME+"-v"+DRILL_VERSION+"-"+ARCHITECTURE+"-"+OS_NAME+".zip ./Build/Drill-CLI-"+OS_NAME+"-x86_64-release/*")
    print(".zips created")

def packageDeb():

    def packageCLIDeb():
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
            CLI_CONTROL_FILE = DEB_CONTROL_FILE     \
            + "\nVersion: "+DRILL_VERSION           \
            + "\nDepends: "+ DEB_CLI_DEPENDENCIES   \
            + "\nPackage: "+ DEB_CLI_PACKAGE_NAME   
            text_file.write(CLI_CONTROL_FILE+"\n")
        # build the .deb file
        shell("dpkg-deb --build DEBFILE/CLI/")

        DEB_CLI_NAME = FILENAME_CLI_PRE_NAME+"-v"+DRILL_VERSION+"-"+ARCHITECTURE+".deb"
        shell("mv DEBFILE/CLI.deb Output/"+DEB_CLI_NAME)
        assert(os.path.exists("Output/"+DEB_CLI_NAME))
        if 'TRAVIS_OS_NAME' in os.environ:
            print("Travis OS detected, trying to install the CLI .deb")
            shell("sudo dpkg -i Output/"+DEB_CLI_NAME)
        print("CLI .deb done")
        shell("rm -rf DEBFILE/CLI")
        print("CLI .deb cleanup")

    def packageGTKDeb():
        GTK_BUILD_DIR="Drill-GTK-linux-x86_64-release"
        BUILD_DIR = "Build/"+GTK_BUILD_DIR
        assert(os.path.exists(BUILD_DIR+"/"+DEB_GTK_PACKAGE_NAME))

        # Install binary redirect for /usr/bin and set it executable
        shell("mkdir -p DEBFILE/GTK/usr/bin")
        with open("DEBFILE/GTK/usr/bin/"+DEB_GTK_PACKAGE_NAME, "w") as text_file:
            text_file.write("#!/bin/bash\n/opt/"+DEB_GTK_PACKAGE_NAME+"/"+DEB_GTK_PACKAGE_NAME)
        shell("chmod +x DEBFILE/GTK/usr/bin/"+DEB_GTK_PACKAGE_NAME)

        # Copy all files and install in /opt
        shell("mkdir -p DEBFILE/GTK/opt/")
        shell("cp -r "+BUILD_DIR+"/ DEBFILE/GTK/opt/"+DEB_GTK_PACKAGE_NAME)
        shell("chmod +x DEBFILE/GTK/opt/"+DEB_GTK_PACKAGE_NAME+"/"+DEB_GTK_PACKAGE_NAME)

        # Create .deb control file
        shell("mkdir -p DEBFILE/GTK/DEBIAN")
        with open("DEBFILE/GTK/DEBIAN/control", "w") as text_file:
            GTK_CONTROL_FILE = DEB_CONTROL_FILE     \
            + "\nVersion: "+DRILL_VERSION           \
            + "\nDepends: "+ DEB_GTK_DEPENDENCIES   \
            + "\nPackage: "+ DEB_GTK_PACKAGE_NAME   
            text_file.write(GTK_CONTROL_FILE+"\n")

        # Add desktop file
        shell("mkdir -p DEBFILE/GTK/usr/share/applications")
        desktop_file = "DEBFILE/GTK/usr/share/applications/drill-search-gtk.desktop"
        with open(desktop_file, "w") as text_file:
            text_file.write(GTK_DESKTOP_FILE)
        shell("desktop-file-validate "+desktop_file)

        # Add icon
        shell("mkdir -p DEBFILE/GTK/usr/share/pixmaps")
        shell("cp Assets/icon.svg DEBFILE/GTK/usr/share/pixmaps/drill-search-gtk.svg")

        # Build the .deb file
        shell("dpkg-deb --build DEBFILE/GTK/")

        DEB_GTK_NAME = FILENAME_GTK_PRE_NAME+"-v"+DRILL_VERSION+"-"+ARCHITECTURE+".deb"
        shell("mv DEBFILE/GTK.deb Output/"+DEB_GTK_NAME)
        assert(os.path.exists("Output/"+DEB_GTK_NAME))
        if 'TRAVIS_OS_NAME' in os.environ:
            print("Travis OS detected, trying to install the GTK .deb")
            shell("sudo dpkg -i Output/"+DEB_GTK_NAME)
        print("GTK .deb done")
        shell("rm -rf DEBFILE/GTK")
        print("GTK .deb cleanup")

    packageCLIDeb()
    packageGTKDeb()


def packageAppImage():
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

    APP_IMAGE_SCRIPT = '''
app: Drill
script: 
 - echo
 - mv ../drill-search-gtk.desktop .
 - mv ../drill-search-gtk.svg .
 - cp -r ../../Build/Drill-GTK-linux-x86_64-release/* usr/bin
'''

    with open("APP_IMAGE_SCRIPT.yml", "w") as text_file:
            text_file.write(APP_IMAGE_SCRIPT)
    shell("bash -ex ./pkg2appimage APP_IMAGE_SCRIPT.yml")

    
    APPIMAGE_NAME = FILENAME_GTK_PRE_NAME+"-v"+DRILL_VERSION+"-"+ARCHITECTURE+".AppImage"


    shell("mv out/*.AppImage Output/"+APPIMAGE_NAME)
    assert(os.path.exists("Output/"+APPIMAGE_NAME))
    print("AppImage done.")
    shell("rm -rf Drill")
    shell("rmdir out")
    shell("rm pkg2appimage")
    shell("rm APP_IMAGE_SCRIPT.yml")
    print("AppImage cleanup")

def packagePortables():
    if platform == "linux" or platform == "linux2":
        packageAppImage()
        #packageSnap()
        #packageFlatpak()

def packageInstallers():
    if platform == "linux" or platform == "linux2":
        packageDeb()
        # packageRpm()

if __name__ == "__main__":

    # Get version to build
    try:
        DRILL_VERSION = os.environ['TRAVIS_BUILD_NUMBER']
    except KeyError:
        DRILL_VERSION = LOCAL_VERSION_NUMBER

    # Write version to build to DRILL_VERSION file so every tool can easily read it
    with open("DRILL_VERSION","w") as drill_version:
        drill_version.write(DRILL_VERSION)

    # Install D if not found
    if find_executable("dub") is None:
        dub = installD()

    # Create output folder
    if not os.path.exists(OUTPUT_FOLDER):
        os.mkdir(OUTPUT_FOLDER)

    if len(argv) == 1:
        buildCLI(dub)
        buildUI(dub)
        createZips()
        packagePortables()
        packageInstallers()
        print("All builds done.")

    # Useful args for local testing
    if len(argv) == 2:
        if argv[1] == "appimage":
            buildUI(dub)
            packageAppImage()
            exit(0)
        if argv[1] == "deb":
            buildCLI(dub)
            buildUI(dub)
            packageDeb()
            exit(0)
    print("Bye!")
