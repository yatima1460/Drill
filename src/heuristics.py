import os

import sys
from typing import List
from functools import lru_cache
from utils import get_resource_path


WORDS_ALPHA = None

@lru_cache(maxsize=10240)
def is_any_token_in_english_dictionary(text: str) -> bool:
    """
    Checks if any token in the given text is in the English dictionary.
    """
    global WORDS_ALPHA
    if WORDS_ALPHA is None:
        try:
            with open(get_resource_path(os.path.join('assets', 'wordsalpha.txt')), 'r') as f:
                WORDS_ALPHA = set(line.strip() for line in f)
        except Exception as e:
            print(f"Error loading dictionary: {e}")
            WORDS_ALPHA = set()
    return any(token.lower() in WORDS_ALPHA for token in text.split())

@lru_cache(maxsize=512)
def is_in_english_dictionary(word: str) -> bool:
    """
    Checks if the given word is in the English dictionary.
    """
    global WORDS_ALPHA
    if WORDS_ALPHA is None:
        try:
            with open(get_resource_path(os.path.join('assets', 'wordsalpha.txt')), 'r') as f:
                WORDS_ALPHA = set(line.strip() for line in f)
        except Exception as e:
            print(f"Error loading dictionary: {e}")
            WORDS_ALPHA = set()
    return word in WORDS_ALPHA  
    

@lru_cache(maxsize=512)
def get_root_directories():
    roots = set()
    
    
    if sys.platform == 'win32':
        # Windows: all drives
        import ctypes
        bitmask = ctypes.windll.kernel32.GetLogicalDrives()
        drives = []
        for i in range(26):
            if bitmask & (1 << i):
                drive_letter = chr(65 + i)
                drive_path = f"{drive_letter}:\\"
                # Skip A: and B: to avoid potential hangs on floppy drives
                if drive_letter in ('A', 'B'):
                    continue
                
                # Check drive type to avoid hanging on empty CD-ROM drives
                drive_type = ctypes.windll.kernel32.GetDriveTypeW(drive_path)
                # DRIVE_REMOVABLE = 2, DRIVE_FIXED = 3, DRIVE_REMOTE = 4, DRIVE_CDROM = 5
                if drive_type in (2, 3, 4):  # Skip CD-ROMs and unknown types
                    drives.append(drive_path)
        
        roots.update(set(drives))
        
        # Add important folders
        userprofile = os.environ.get('USERPROFILE')
        important_folders = []
        if userprofile:
            important_folders.extend([
                userprofile,
                os.path.join(userprofile, 'Desktop'),
                os.path.join(userprofile, 'Documents'),
                os.path.join(userprofile, 'Downloads'),
                os.path.join(userprofile, 'Pictures'),
                os.path.join(userprofile, 'Videos'),
                os.path.join(userprofile, 'Music')
            ])
            # Add programs
            important_folders.append(os.path.join(userprofile, 'AppData', 'Local', 'Programs'))
        
        # add programs x86 and program files for all detected drives
        for drive in drives:
            important_folders.append(os.path.join(drive, 'Program Files (x86)'))
            important_folders.append(os.path.join(drive, 'Program Files'))

        # Add common game paths and their subfolders
        game_library_roots = [
            os.path.join('C:\\', 'GOG Games')
        ]

        # Check all drives for Steam and Epic libraries
        for drive in drives:
            game_library_roots.append(os.path.join(drive, 'Program Files (x86)', 'Steam', 'steamapps', 'common'))
            game_library_roots.append(os.path.join(drive, 'Program Files', 'Epic Games'))
            game_library_roots.append(os.path.join(drive, 'SteamLibrary', 'steamapps', 'common'))


        for game_root in game_library_roots:
            if os.path.exists(game_root):
                important_folders.append(game_root)
                try:
                    for subfolder in os.listdir(game_root):
                        full_path = os.path.join(game_root, subfolder)
                        if os.path.isdir(full_path):
                            important_folders.append(full_path)
                except PermissionError:
                    pass
                        
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
        roots.add(home)
    return roots

def system_directories():
    """
    Returns a list of system directories that are not considered important
    """
    if os.name == 'nt':
        return [
            'C:\\Windows',
            'C:\\ProgramData',
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