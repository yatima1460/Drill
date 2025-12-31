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
    
    # Get all logical drives on Windows for expansion
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

    # Read roots from file
    try:
        if sys.platform == 'win32':
            config_filename = 'roots_windows.txt'
        elif sys.platform == 'darwin':
            config_filename = 'roots_mac.txt'
        else:
            config_filename = 'roots_linux.txt'
            
        config_path = get_resource_path(os.path.join('assets', config_filename))
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Expand environment variables and ~
                    line = os.path.expanduser(os.path.expandvars(line))
                    
                    paths_to_process = []
                    if line.startswith('*:'):
                        suffix = line[2:].lstrip('\\/')
                        for drive in drives:
                            paths_to_process.append(os.path.join(drive, suffix))
                    else:
                        paths_to_process.append(line)
                        
                    for path in paths_to_process:
                        if path.endswith('*'):
                            base_path = path[:-1].rstrip('\\/')
                            if os.path.exists(base_path) and os.path.isdir(base_path):
                                try:
                                    for entry in os.listdir(base_path):
                                        full_path = os.path.join(base_path, entry)
                                        if os.path.isdir(full_path):
                                            roots.add(os.path.normpath(full_path))
                                except PermissionError:
                                    pass
                        else:
                            if os.path.exists(path):
                                roots.add(os.path.normpath(path))
                                
    except Exception as e:
        print(f"Error reading {config_filename}: {e}")

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