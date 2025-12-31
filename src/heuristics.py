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
    
    # Add all logical drives on Windows
    drives = []
    if sys.platform == 'win32':
        import ctypes
        bitmask = ctypes.windll.kernel32.GetLogicalDrives()
        for i in range(26):
            if bitmask & (1 << i):
                drive_letter = chr(65 + i)
                drive_path = f"{drive_letter}:\\"
                if drive_letter in ('A', 'B'):
                    continue
                drive_type = ctypes.windll.kernel32.GetDriveTypeW(drive_path)
                if drive_type in (2, 3, 4):  # Removable, Fixed, Remote
                    drives.append(drive_path)
        roots.update(set(drives))

    # 2. Read important folders from file
    important_folders = []
    try:
        if sys.platform == 'win32':
            config_filename = 'important_folders_windows.txt'
        elif sys.platform == 'darwin':
            config_filename = 'important_folders_mac.txt'
        else:
            config_filename = 'important_folders_linux.txt'
            
        config_path = get_resource_path(os.path.join('assets', config_filename))
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Expand environment variables and ~
                    path = os.path.expanduser(os.path.expandvars(line))
                    if os.path.exists(path):
                        important_folders.append(os.path.normpath(path))
    except Exception as e:
        print(f"Error reading {config_filename}: {e}")

    # Dynamic discovery for games (Steam libraries on other drives)
    if sys.platform == 'win32':
        game_library_roots = []
        for drive in drives:
            # Common SteamLibrary pattern on non-C drives
            game_library_roots.append(os.path.normpath(os.path.join(drive, 'SteamLibrary', 'steamapps', 'common')))
        
        for game_root in game_library_roots:
            if os.path.exists(game_root):
                important_folders.append(game_root)
                try:
                    for subfolder in os.listdir(game_root):
                        full_path = os.path.normpath(os.path.join(game_root, subfolder))
                        if os.path.isdir(full_path):
                            important_folders.append(full_path)
                except PermissionError:
                    pass

    # Apple specific dynamic discovery (Network drives)
    if sys.platform == 'darwin':
        try:
            network_drives = ["/Volumes" + os.sep + folder for folder in os.listdir('/Volumes') if os.path.isdir(os.path.join('/Volumes', folder))]
            important_folders.extend(network_drives)
        except Exception:
            pass

    # Add all discovered folders to roots
    roots.update(set([os.path.normpath(folder) for folder in important_folders if os.path.exists(folder)]))
    
    if not roots:
        # Fallback to home directory if nothing else found
        roots.add(os.path.normpath(os.path.expanduser('~')))
        
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