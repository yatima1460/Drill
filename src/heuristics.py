

import os

import sys
from typing import List
from functools import lru_cache


WORDS_ALPHA = None

@lru_cache(maxsize=10240)
def is_any_token_in_english_dictionary(text: str) -> bool:
    """
    Checks if any token in the given text is in the English dictionary.
    """
    global WORDS_ALPHA
    if WORDS_ALPHA is None:
        with open(os.path.join(os.path.dirname(__file__), 'assets', 'wordsalpha.txt'), 'r') as f:
            WORDS_ALPHA = set(line.strip() for line in f)
    return any(token.lower() in WORDS_ALPHA for token in text.split())

@lru_cache(maxsize=512)
def is_in_english_dictionary(word: str) -> bool:
    """
    Checks if the given word is in the English dictionary.
    """
    global WORDS_ALPHA
    if WORDS_ALPHA is None:
        with open(os.path.join(os.path.dirname(__file__), 'assets', 'wordsalpha.txt'), 'r') as f:
            WORDS_ALPHA = set(line.strip() for line in f)
    return word in WORDS_ALPHA  
    

@lru_cache(maxsize=512)
def get_root_directories():
    roots = set()
    
    
    if sys.platform == 'win32':
        # Windows: all drives
        drives = [f"{d}:\\" for d in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' if os.path.exists(f"{d}:\\")]
        roots.update(set(drives))
        # Add important folders
        userprofile = os.environ['USERPROFILE']
        important_folders = [
            os.path.join(userprofile, 'Desktop'),
            os.path.join(userprofile, 'Documents'),
            os.path.join(userprofile, 'Downloads'),
            os.path.join(userprofile, 'Pictures'),
            os.path.join(userprofile, 'Videos'),
            os.path.join(userprofile, 'Music')
            # TODO: Recent files folder
            
        ]
        # Add programs
        important_folders.append(os.path.join(userprofile, 'AppData', 'Local', 'Programs'))
        # add programs x86 and program files in C:
        important_folders.append(os.path.join('C:\\', 'Program Files (x86)'))
        important_folders.append(os.path.join('C:\\', 'Program Files'))
        # Add important folders to roots (only if they exist)
        roots.update(set([folder for folder in important_folders if os.path.exists(folder)]))
    elif sys.platform == 'darwin':
        # macOS: main user folders and Applications
        home = os.path.expanduser('~')
        important_folders = [
            home,
            os.path.join(home, 'Applications'),
            os.path.join(home, 'Desktop'),
            os.path.join(home, 'Documents'),
            os.path.join(home, 'Downloads'),
            os.path.join(home, 'Pictures'),
            os.path.join(home, 'Movies'),
            os.path.join(home, 'Music'),
            #iCloud
            os.path.join(home, 'Library', 'Mobile Documents', 'com~apple~CloudDocs'),
            '/Applications',
            '/',
        ]
        # Keep in mind that on Mac:
        # /Volumes
        # /Volumes/Macintosh HD/Volumes
        # /System/Volumes/Data/Volumes/
        # will point to the same root directory
        #
        # Add network drives
        network_drives = ["/Volumes" + os.sep + folder for folder in os.listdir('/Volumes') if os.path.isdir(os.path.join('/Volumes', folder))]
        # Add root
        important_folders.extend(network_drives)
        #important_folders.extend([os.path.join(folder, subfolder) for folder in network_drives for subfolder in os.listdir(folder)])
        #important_folders.append("/")
       
        roots.update(set([folder for folder in important_folders if os.path.exists(folder)]))
    else:
        # Linux/Other: just the home directory
        home = os.path.expanduser('~')
        roots.update(home)
    return roots

def system_directories():
    """
    Returns a list of system directories that are not considered important
    """
    if os.name == 'nt':
        return [
            'C:\\Windows',
            'C:\\ProgramData',
            'C:\\Program Files',
            'C:\\Program Files (x86)',
            'C:\\Users',
            'C:\\$Recycle.Bin',
            'C:\\System Volume Information'
        ]
    elif sys.platform == 'darwin':
        return [
            '/System',
            '/Library',
            '/private',
            '/usr',
            '/bin',
            '/sbin'
        ]
    else:
        return [
            '/',
            '/etc',
            '/var',
            '/usr',
            '/bin',
            '/sbin'
        ]
    
def is_in_system_dirs(path: str) -> bool:
    for system_dir in system_directories():
        if path.startswith(system_dir):
            return True
    return False