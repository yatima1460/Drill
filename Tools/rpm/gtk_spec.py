#!/usr/bin/env python


import os
cwd = os.getcwd()
print("CWD",cwd)
# with open("../../DRILL_VERSION", 'U') as myfile:
#     DRILL_VERSION=myfile.read()


# print("DRILL_VERSION",DRILL_VERSION)
import distutils.core




# if __name__ == "__main__":
#     name = 'drill-search'


#     build_path = "../../Source/Frontend/GTK/Build/Drill-GTK-linux-x86_64-release/"

    
#     # cwd = os.getcwd()
#     # print("CWD",cwd)
    
#     distutils.core.setup(
#         name=name,
#         # version=DRILL_VERSION,
#         author="Federico Santamorena",
#         author_email="federico@santamorena.me",
#         url="https://github.com/yatima1460/Drill",
#         description="Search files without indexing, but clever crawling",
#         long_description="Long description of your tool",
#         license="GPL-2.0",

#         scripts=[build_path+"drill-search-gtk"],
#         data_files=[
#             (build_path+"drill-search-gtk", ["drill-search-gtk"]),
#         ],
#     )



from distutils.core import setup

#This is a list of files to install, and where
#(relative to the 'root' dir, where setup.py is)
#You could be more specific.
files = ["$RPM_BUILD_ROOT/../../Source/Frontend/GTK/Build/Drill-GTK-linux-x86_64-release/*"]

setup(name = "Drill",
    version = "100",
    description = "yadda yadda",
    author = "myself and I",
    author_email = "email@someplace.com",
    url = "whatever",
    arch = "amd64",
    #Name the folder where your packages live:
    #(If you have other packages (dirs) or modules (py files) then
    #put them into the package directory - they will be found 
    #recursively.)
    # packages = ['package'],
    #'package' package must contain files (see list above)
    #I called the package 'package' thus cleverly confusing the whole issue...
    #This dict maps the package name =to=> directories
    #It says, package *needs* these files.
    package_data = {'package' : files },
    #'runner' is in the root.
    #scripts = ["drill-search-gtk"],
    long_description = """
                        - At least 1 thread per mount point
                        - Use as much RAM as possible for caching stuff
                        - Try to avoid "black hole folders" using a regex based blocklist in which the crawler will never come out and never scan useful files (`node_modules`,`Windows`,etc)
                        - **Intended for desktop users**, no obscure Linux files and system files scans
                        - Use priority lists to first scan important folders.
                        - Betting on the future: slowly being optimized for SSDs/M.2 or fast RAID arrays
                      """ 
    #
    #This next part it for the Cheese Shop, look a little down the page.
    #classifiers = []     
) 
    